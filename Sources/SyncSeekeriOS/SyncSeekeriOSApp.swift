import SwiftUI
import SyncSeeker

@main
struct SyncSeekeriOSApp: App {
    var body: some Scene {
        WindowGroup {
            iPadRootView()
        }
    }
}

// MARK: - State adapter (SyncListener → Document/Folder)

@Observable @MainActor
final class iPadState {
    var selectedDocument: SyncSeeker.Document?
    var searchText: String = ""
    var selectedFolderPath: URL?

    let listener = SyncListener()

    init() {
        listener.start()
    }

    var allDocuments: [SyncSeeker.Document] {
        listener.receivedFiles.map(\.asDocument)
    }

    var folders: [SyncSeeker.Folder] {
        let dirs = Set(
            listener.receivedFiles.compactMap { file -> String? in
                let parts = file.relativePath.components(separatedBy: "/")
                return parts.count > 1 ? parts[0] : nil
            }
        )
        return dirs.sorted().map { name in
            SyncSeeker.Folder(
                id: UUID(),
                name: name,
                path: listener.syncDirectory.appendingPathComponent(name),
                children: [],
                documents: []
            )
        }
    }

    var displayedDocuments: [SyncSeeker.Document] {
        var docs = allDocuments
        if let folder = selectedFolderPath {
            docs = docs.filter { $0.path.path.hasPrefix(folder.path + "/") }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            docs = docs.filter {
                $0.name.lowercased().contains(q) ||
                $0.tags.contains { $0.lowercased().contains(q) }
            }
        }
        return docs
    }
}

// MARK: - ReceivedFile → Document

extension ReceivedFile {
    var asDocument: SyncSeeker.Document {
        let ext = url.pathExtension.lowercased()
        let fileType: SyncSeeker.FileType
        switch ext {
        case "pdf":             fileType = .pdf
        case "md", "markdown":  fileType = .markdown
        case "txt", "text":     fileType = .plainText
        case "rtf", "rtfd":     fileType = .richText
        default:                fileType = .unknown
        }
        var tags: [String] = []
        let xattrs = XattrIO.readAll(at: url)
        if let data = xattrs["com.apple.metadata:_kMDItemUserTags"],
           let parsed = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String] {
            tags = parsed
        }
        return SyncSeeker.Document(
            id: id, name: name, path: url,
            size: size, modifiedDate: modifiedDate,
            fileType: fileType, tags: tags
        )
    }
}

// MARK: - Root view (Mac SearchView と同じ 3 カラム構成)

struct iPadRootView: View {
    @State private var state = iPadState()

    var body: some View {
        NavigationSplitView {
            iPadSidebarView(state: state)
        } content: {
            FileListView(
                documents: state.displayedDocuments,
                selection: Bindable(state).selectedDocument
            )
            .navigationTitle(sectionTitle)
            .searchable(text: Bindable(state).searchText, prompt: "ファイル名・タグで検索...")
        } detail: {
            if let doc = state.selectedDocument {
                DocumentPreviewView(document: doc)
            } else {
                ContentUnavailableView(
                    "ドキュメントを選択",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("左のリストからドキュメントを選んでください")
                )
            }
        }
    }

    private var sectionTitle: String {
        if !state.searchText.isEmpty { return "検索: \(state.searchText)" }
        if let folder = state.selectedFolderPath { return folder.lastPathComponent }
        return "すべて"
    }
}

// MARK: - Sidebar (Mac SidebarView と同構成)

struct iPadSidebarView: View {
    var state: iPadState

    var body: some View {
        List {
            Section("ライブラリ") {
                Button {
                    state.selectedFolderPath = nil
                } label: {
                    Label("すべて", systemImage: "folder")
                        .badge(state.allDocuments.count)
                }
                .buttonStyle(.plain)
                .fontWeight(state.selectedFolderPath == nil ? .semibold : .regular)
            }

            if !state.folders.isEmpty {
                Section("フォルダ") {
                    ForEach(state.folders) { folder in
                        Button {
                            state.selectedFolderPath = folder.path
                        } label: {
                            Label(folder.name, systemImage: "folder.fill")
                        }
                        .buttonStyle(.plain)
                        .fontWeight(state.selectedFolderPath == folder.path ? .semibold : .regular)
                    }
                }
            }

            Section("受信") {
                HStack {
                    Image(systemName: state.listener.isListening
                          ? "antenna.radiowaves.left.and.right"
                          : "antenna.radiowaves.left.and.right.slash")
                        .foregroundStyle(state.listener.isListening ? .green : .secondary)
                    Text(state.listener.statusText)
                        .font(.caption)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("SyncSeeker")
    }
}
