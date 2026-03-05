import Foundation
import SwiftUI
import SyncSeeker

struct SearchView: View {
    @Bindable var state: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView(state: state)
        } content: {
            FileListView(
                documents: state.displayedDocuments,
                selection: $state.selectedDocument
            )
            .navigationTitle(sectionTitle)
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
        .searchable(text: $state.searchText, placement: .toolbar, prompt: "ファイル名・タグで検索...")
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
                    Image(systemName: state.isConnected ? "cable.connector" : "cable.connector.slash")
                        .foregroundStyle(state.isConnected ? .green : .secondary)
                    Text(state.isConnected ? "USB 接続中" : "未接続")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("sync-seeker")
    }
}
