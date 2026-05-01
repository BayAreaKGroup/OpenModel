import Foundation
import CryptoKit

enum AppRuntimeError: Error, LocalizedError {
    case missingURL
    case modelNotDownloaded
    case checksumMismatch
    case runtimeNotReady
    
    var errorDescription: String? {
        switch self {
        case .missingURL:
            return "Invalid model URL."
        case .modelNotDownloaded:
            return "Model file is not downloaded."
        case .checksumMismatch:
            return "Model checksum verification failed."
        case .runtimeNotReady:
            return "Runtime is not loaded."
        }
    }
}

actor LocalModelStorage {
    private let fm = FileManager.default
    
    private var rootURL: URL {
        let root = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return root.appendingPathComponent("Models", isDirectory: true)
    }
    
    func ensureDirectories() throws {
        if !fm.fileExists(atPath: rootURL.path) {
            try fm.createDirectory(at: rootURL, withIntermediateDirectories: true)
        }
    }
    
    func modelDirectory(for modelID: String) async throws -> URL {
        try ensureDirectories()
        let dir = rootURL.appendingPathComponent(modelID, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    func modelFileURL(for item: ModelCatalogItem) async -> URL {
        let dir = rootURL.appendingPathComponent(item.id, isDirectory: true)
        return dir.appendingPathComponent(item.fileName)
    }
    
    func exists(_ item: ModelCatalogItem) async -> Bool {
        do {
            let path = try await modelDirectory(for: item.id).appendingPathComponent(item.fileName)
            return fm.fileExists(atPath: path.path)
        } catch {
            return false
        }
    }
    
    func fileSize(_ item: ModelCatalogItem) async -> Int64? {
        do {
            let path = try await modelDirectory(for: item.id).appendingPathComponent(item.fileName)
            guard fm.fileExists(atPath: path.path) else { return nil }
            let attrs = try fm.attributesOfItem(atPath: path.path)
            return (attrs[.size] as? NSNumber)?.int64Value
        } catch {
            return nil
        }
    }
    
    func delete(_ item: ModelCatalogItem) async throws {
        let dir = try await modelDirectory(for: item.id)
        if fm.fileExists(atPath: dir.path) {
            try fm.removeItem(at: dir)
        }
    }
}

actor ModelDownloadManager {
    func download(item: ModelCatalogItem, to destination: URL) async throws -> URL {
        guard let source = item.downloadURL else { throw AppRuntimeError.missingURL }
        let directory = destination.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        
        let (tempURL, response) = try await URLSession.shared.download(from: source)
        guard
            let http = response as? HTTPURLResponse,
            (200...299).contains(http.statusCode)
        else {
            throw AppRuntimeError.missingURL
        }
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }
    
    func verify(_ item: ModelCatalogItem, fileURL: URL) async throws {
        guard let expected = item.sha256 else { return }
        let data = try Data(contentsOf: fileURL)
        let actual = data.sha256Hex.lowercased()
        if actual != expected.lowercased() {
            throw AppRuntimeError.checksumMismatch
        }
    }
}

protocol LocalLLMRuntime: Sendable {
    func preload(model: ModelCatalogItem, localURL: URL) async throws
    func unload() async
    func generate(prompt: String, onToken: @Sendable (String) async -> Void) async throws
}

actor MockLLMRuntime: LocalLLMRuntime {
    private var loadedModelID: String?

    func preload(model: ModelCatalogItem, localURL: URL) async throws {
        loadedModelID = model.id
        try await Task.sleep(for: .milliseconds(250))
    }
    
    func unload() async {
        loadedModelID = nil
    }
    
    func generate(prompt: String, onToken: @Sendable (String) async -> Void) async throws {
        guard let id = loadedModelID else { throw AppRuntimeError.runtimeNotReady }
        let response = "Mock output from \(id): \(prompt)"
        for char in response {
            try Task.checkCancellation()
            await onToken(String(char))
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}

extension Data {
    var sha256Hex: String {
        SHA256.hash(data: self).map { String(format: "%02x", $0) }.joined()
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var catalog: [ModelCatalogItem] = []
    @Published var statusByModel: [String: DownloadState] = [:]
    @Published var activeModelID: String?
    @Published var statusMessage: String?
    @Published var isCatalogLoading = false
    
    let storage = LocalModelStorage()
    private let downloader = ModelDownloadManager()
    private let runtime: LocalLLMRuntime = MockLLMRuntime()
    
    init() {
        Task { await refreshCatalog() }
    }
    
    func refreshCatalog() async {
        isCatalogLoading = true
        catalog = await CatalogService().loadCatalog()
        isCatalogLoading = false
        
        for item in catalog {
            let downloaded = await storage.exists(item)
            statusByModel[item.id] = downloaded ? .downloaded : .notDownloaded
        }
    }
    
    func state(for model: ModelCatalogItem) -> DownloadState {
        statusByModel[model.id] ?? .notDownloaded
    }
    
    func download(_ item: ModelCatalogItem) async {
        statusByModel[item.id] = .downloading(0.02)
        do {
            let dest = await storage.modelFileURL(for: item)
            let local = try await downloader.download(item: item, to: dest)
            try await downloader.verify(item, fileURL: local)
            statusByModel[item.id] = .downloaded
            statusMessage = "Downloaded: \(item.name)"
        } catch {
            statusByModel[item.id] = .failed(error.localizedDescription)
            statusMessage = "Download error: \(error.localizedDescription)"
        }
    }
    
    func launch(_ item: ModelCatalogItem) async {
        let downloaded = await storage.exists(item)
        guard downloaded else {
            statusMessage = "Model not downloaded: \(item.name)"
            return
        }
        guard item.runtime == .gguf else {
            statusMessage = "This runtime is not supported in this sample. Use GGUF sample model."
            return
        }
        
        guard let size = await storage.fileSize(item), size > 0 else {
            statusMessage = "Model file is invalid or empty: \(item.name)"
            return
        }
        
        if item.runtime == .gguf && item.id.contains("TinyLlama-1.1B-Chat") {
            statusMessage = "TinyLlama launch is mocked only. For real inference, integrate a local runtime adapter."
        }
        
        do {
            let modelFile = await storage.modelFileURL(for: item)
            try await runtime.preload(model: item, localURL: modelFile)
            activeModelID = item.id
            statusMessage = "Launched \(item.name)"
        } catch {
            statusMessage = "Launch error: \(error.localizedDescription)"
        }
    }
    
    func unload() async {
        await runtime.unload()
        activeModelID = nil
        statusMessage = "Runtime unloaded"
    }
    
    func infer(prompt: String, onToken: @MainActor @escaping (String) -> Void) async {
        guard activeModelID != nil else {
            statusMessage = "No active model."
            return
        }
        do {
            try await runtime.generate(prompt: prompt) { token in
                await MainActor.run { onToken(token) }
            }
        } catch {
            statusMessage = "Inference error: \(error.localizedDescription)"
        }
    }
    
    func installedModels() -> [ModelCatalogItem] {
        catalog.filter { stateForInstalled($0.id) }
    }
    
    private func stateForInstalled(_ modelID: String) -> Bool {
        if case .downloaded = statusByModel[modelID] { return true }
        if case .downloading(_) = statusByModel[modelID] { return true }
        return false
    }
    
    func delete(_ item: ModelCatalogItem) async {
        do {
            try await storage.delete(item)
            await runtime.unload()
            statusByModel[item.id] = .notDownloaded
            if activeModelID == item.id { activeModelID = nil }
            statusMessage = "Deleted: \(item.name)"
        } catch {
            statusMessage = "Delete error: \(error.localizedDescription)"
        }
    }
}

struct CatalogService {
    func loadCatalog() async -> [ModelCatalogItem] {
        guard
            let url = Bundle.main.url(forResource: "sample_models", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([ModelCatalogItem].self, from: data)
        else {
            return ModelCatalogItem.fallbackCatalog
        }
        return decoded
    }
}
