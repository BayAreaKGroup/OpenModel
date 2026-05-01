import Foundation

enum ModelModality: String, Codable, CaseIterable {
    case text, image, audio, video
}

enum RuntimeFormat: String, Codable {
    case gguf
    case coreml
    case mlx
    case unknown
}

enum DownloadState: Equatable {
    case notDownloaded
    case downloading(Double)
    case downloaded
    case failed(String)
    
    var title: String {
        switch self {
        case .notDownloaded: "not downloaded"
        case .downloading: "downloading"
        case .downloaded: "ready"
        case .failed(let reason): "failed: \(reason)"
        }
    }
    
    var progress: Double? {
        if case let .downloading(value) = self { value }
        else { nil }
    }
}

struct ModelCatalogItem: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String
    let provider: String
    let license: String
    let sizeBytes: Int
    let runtime: RuntimeFormat
    let modalities: [ModelModality]
    let downloadURLString: String
    let fileName: String
    let sha256: String?
    
    var downloadURL: URL? { URL(string: downloadURLString) }
    
    var sizeMB: String {
        let mb = Double(max(sizeBytes, 0)) / 1024 / 1024
        if sizeBytes == 0 { return "unknown" }
        return String(format: "%.1f MB", mb)
    }
    
    static let fallbackCatalog: [ModelCatalogItem] = [
        .init(
            id: "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF",
            name: "TinyLlama 1.1B Chat",
            description: "Small instruction model for quick local test.",
            provider: "TheBloke",
            license: "Apache-2.0",
            sizeBytes: 0,
            runtime: .gguf,
            modalities: [.text],
            downloadURLString: "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf",
            fileName: "tinyllama-1.1b-chat-v1.0.gguf",
            sha256: nil
        ),
        .init(
            id: "HuggingFaceH4/zephyr-7b-beta-GGUF",
            name: "Zephyr 7B Beta",
            description: "Instruction model for general question/answer.",
            provider: "HuggingFaceH4",
            license: "Apache-2.0",
            sizeBytes: 0,
            runtime: .gguf,
            modalities: [.text],
            downloadURLString: "https://huggingface.co/TheBloke/zephyr-7b-beta-GGUF/resolve/main/zephyr-7b-beta.Q4_K_M.gguf",
            fileName: "zephyr-7b-beta.gguf",
            sha256: nil
        )
    ]
}
