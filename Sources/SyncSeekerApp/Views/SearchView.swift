import Foundation
import SwiftUI
import SyncSeeker

#if os(macOS)
struct SearchView: View {
    @Bindable var state: AppState
    @State private var showingNewFolderAlert = false
    @State private var newFolderName = "New Folder"

    var body: some View {
        NavigationSplitView {
            SidebarView(state: state)
        } content: {
            FileListView(
                documents: state.displayedDocuments,
                selection: $state.selectedDocument,
                onTrash: { doc in
                    try? state.trashFile(doc)
                },
                onRename: { doc, newName in
                    do {
                        try state.renameFile(doc, to: newName)
                    } catch {
                        print("Failed to rename file: \(error)")
                    }
                },
                folders: state.folders,
                onDuplicate: { doc in
                    Task { try? await state.duplicateFile(doc) }
                },
                onMove: { doc, destination in
                    Task { try? await state.moveFile(doc, to: destination) }
                },
                onDropFiles: { urls in
                    state.importFiles(urls: urls, to: state.selectedFolderPath)
                }
            )
            .navigationTitle(sectionTitle)
            .searchable(text: $state.searchText, placement: .toolbar, prompt: "ファイル名・タグで検索...")
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newFolderName = "New Folder"
                    showingNewFolderAlert = true
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                .keyboardShortcut("n", modifiers: [.shift, .command])
            }
        }
        .alert("New Folder", isPresented: $showingNewFolderAlert) {
            TextField("Folder Name", text: $newFolderName)
            Button("Cancel", role: .cancel) { }
            Button("Create") {
                try? state.createFolder(named: newFolderName, inside: state.selectedFolderPath)
            }
        }
    }

    private var sectionTitle: String {
        if !state.searchText.isEmpty {
            return "検索: \(state.searchText)"
        }
        if let folder = state.selectedFolderPath {
            return folder.lastPathComponent
        }
        return "すべて"
    }
}

struct SidebarView: View {
    @Bindable var state: AppState

    var body: some View {
        List {
            Section("ライブラリ") {
                Button {
                    state.selectFolder(nil)
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
                            state.selectFolder(folder.path)
                        } label: {
                            Label(folder.name, systemImage: "folder.fill")
                        }
                        .buttonStyle(.plain)
                        .fontWeight(state.selectedFolderPath == folder.path ? .semibold : .regular)
                    }
                }
            }

            Section("接続") {
                HStack {
                    Image(systemName: state.menuBarState.iconName)
                        .foregroundStyle(connectionColor(state.connectionState))
                    Text(state.menuBarState.statusText)
                        .font(.caption)
                }
                

                if case .transferring(let sent, let total, let file) = state.transferState {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file).font(.caption2).lineLimit(1)
                        if total > 0 {
                            ProgressView(value: Double(sent), total: Double(total))
                        } else {
                            ProgressView()
                        }
                        Text("\(sent) / \(total)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("sync-seeker")
    }

    private func connectionColor(_ state: ConnectionState) -> Color {
        switch state {
        case .connected: return .green
        case .connecting: return .yellow
        case .error: return .red
        case .disconnected: return .secondary
        }
    }
}
#endif
