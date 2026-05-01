import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        TabView {
            CatalogView()
                .tabItem {
                    Label("Browse", systemImage: "square.stack")
                }
            
            PlaygroundView()
                .tabItem {
                    Label("Playground", systemImage: "bolt")
                }
            
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "internaldrive")
                }
        }
    }
}

private struct CatalogView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        NavigationStack {
            List {
                if appState.catalog.isEmpty && appState.isCatalogLoading {
                    ProgressView("Loading catalog")
                }
                
                ForEach(appState.catalog) { item in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(item.name).font(.headline)
                        Text(item.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Text(item.provider)
                            Text("•")
                            Text(item.runtime.rawValue.uppercased())
                            Text("•")
                            Text(item.sizeMB)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        
                        statusView(item)
                        
                        HStack {
                            Button("Download") { Task { await appState.download(item) } }
                                .buttonStyle(.borderedProminent)
                                .disabled(!canDownload(item))
                            
                            Button("Launch") { Task { await appState.launch(item) } }
                                .buttonStyle(.bordered)
                                .disabled(!isDownloaded(item))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Model Catalog")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh") { Task { await appState.refreshCatalog() } }
                }
            }
        }
    }
    
    private func isDownloaded(_ item: ModelCatalogItem) -> Bool {
        if case .downloaded = appState.state(for: item) { return true }
        return false
    }
    
    private func canDownload(_ item: ModelCatalogItem) -> Bool {
        switch appState.state(for: item) {
        case .notDownloaded, .failed:
            return true
        default:
            return false
        }
    }
    
    private func statusView(_ item: ModelCatalogItem) -> some View {
        let state = appState.state(for: item)
        return HStack(spacing: 12) {
            Text(state.title)
                .padding(6)
                .font(.caption)
                .background(.thinMaterial)
                .clipShape(Capsule())
            if let progress = state.progress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
            }
            if case .failed(let message) = state {
                Text(message).foregroundStyle(.red).font(.caption2)
            }
        }
    }
}

private struct PlaygroundView: View {
    @EnvironmentObject private var appState: AppState
    @State private var prompt = "Write a concise summary of edge AI model testing."
    @State private var isRunning = false
    @State private var response = ""
    @State private var sessionTask: Task<Void, Never>?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let active = appState.activeModelID,
                   let model = appState.catalog.first(where: { $0.id == active }) {
                    HStack {
                        Text("Active: \(model.name)")
                            .font(.subheadline)
                        Spacer()
                        Button("Unload") {
                            Task { await appState.unload() }
                        }
                    }
                } else {
                    Text("No active model. Launch one from Browse.")
                        .foregroundStyle(.secondary)
                }
                
                TextEditor(text: $prompt)
                    .frame(height: 160)
                    .padding(8)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                HStack {
                    Button("Run inference") {
                        response = ""
                        isRunning = true
                        let currentPrompt = prompt
                        sessionTask = Task {
                            await appState.infer(prompt: currentPrompt) { token in
                                response.append(token)
                            }
                            await MainActor.run {
                                isRunning = false
                                sessionTask = nil
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning || appState.activeModelID == nil)
                    
                    Button("Stop") {
                        sessionTask?.cancel()
                        sessionTask = nil
                        isRunning = false
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isRunning)
                }
                
                ScrollView {
                    Text(response)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                if let msg = appState.statusMessage {
                    Text(msg).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding()
            .navigationTitle("Playground")
        }
    }
}

private struct LibraryView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        NavigationStack {
            List {
                Section("Installed models") {
                    if appState.installedModels().isEmpty {
                        Text("No downloaded models.").foregroundStyle(.secondary)
                    } else {
                        ForEach(appState.installedModels()) { item in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.name)
                                    Text(item.id).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Delete") {
                                    Task { await appState.delete(item) }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Library")
        }
    }
}
