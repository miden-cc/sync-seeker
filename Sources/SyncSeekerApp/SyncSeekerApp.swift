import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

import SyncSeeker

#if os(macOS)
struct SyncSeekerMacApp: App {
    @State private var appState = AppState()

    init() {
        // swift run 等で直接 CLI から起動された場合でも、Dock に表示してキーボード入力を受け付けるようにする
        #if canImport(AppKit)
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            SearchView(state: appState)
                .frame(minWidth: 800, minHeight: 500)
        }
        .defaultSize(width: 1100, height: 700)

        MenuBarExtra("SyncSeeker", systemImage: appState.menuBarState.iconName) {
            MenuBarContent(state: appState)
        }
    }
}

struct MenuBarContent: View {
    @Bindable var state: AppState

    private var bar: MenuBarState { state.menuBarState }

    var body: some View {
        // Status
        Label(bar.statusText, systemImage: bar.iconName)

        if let lastSync = bar.lastSyncFormatted {
            Text("Last sync: \(lastSync)")
                .font(.caption)
        }

        Divider()

        Text("\(state.allDocuments.count) documents")

        Divider()

        // Actions
        ForEach(bar.availableActions, id: \.self) { action in
            switch action {
            case .syncNow:
                Button("Sync Now") { state.startSync() }
            case .cancelSync:
                Button("Cancel Sync") { state.cancelSync() }
            case .openApp:
                Button("Open SyncSeeker") {
                    NSWorkspace.shared.open(state.syncFolderPath)
                }
            case .quit:
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
        }
    }
    }
}
#endif
