import SwiftUI
import SyncSeeker

@main
struct SyncSeekerMacApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            SearchView(state: appState)
                .frame(minWidth: 800, minHeight: 500)
        }
        .defaultSize(width: 1100, height: 700)

        MenuBarExtra("sync-seeker", systemImage: "cable.connector") {
            MenuBarContent(state: appState)
        }
    }
}

struct MenuBarContent: View {
    @Bindable var state: AppState

    var body: some View {
        Label(
            state.isConnected ? "USB 接続中" : "未接続",
            systemImage: state.isConnected ? "checkmark.circle.fill" : "xmark.circle"
        )

        Divider()

        Text("\(state.allDocuments.count) ドキュメント")

        Divider()

        Button("フォルダを開く") {
            NSWorkspace.shared.open(state.syncFolderPath)
        }

        Button("更新") {
            state.refresh()
        }

        Divider()

        Button("終了") {
            NSApplication.shared.terminate(nil)
        }
    }
}
