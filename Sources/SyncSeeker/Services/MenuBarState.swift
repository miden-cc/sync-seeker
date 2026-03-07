import Foundation

/// メニューバー常駐アイコンの表示状態を管理するモデル。
/// SwiftUI の `MenuBarExtra` から参照して UI をレンダリングする。
public struct MenuBarState {

    public let connection: ConnectionState
    public let transfer: TransferState
    public let lastSyncDate: Date?

    public init(connection: ConnectionState, transfer: TransferState, lastSyncDate: Date?) {
        self.connection = connection
        self.transfer = transfer
        self.lastSyncDate = lastSyncDate
    }

    // MARK: - Icon

    /// SF Symbol 名。
    public var iconName: String {
        if case .transferring = transfer {
            return "arrow.up.arrow.down.circle.fill"
        }

        switch connection {
        case .disconnected: return "arrow.triangle.2.circlepath"
        case .connecting:   return "arrow.triangle.2.circlepath.circle"
        case .connected:    return "checkmark.circle.fill"
        case .error:        return "exclamationmark.triangle"
        }
    }

    // MARK: - Status text

    public var statusText: String {
        switch transfer {
        case .transferring(let progress, let file):
            let pct = Int(progress * 100)
            return "Syncing \(file) (\(pct)%)"
        case .completed(let count, _):
            return "Synced \(count) file(s)."
        case .error(let msg):
            return "Transfer error: \(msg)"
        default:
            break
        }

        switch connection {
        case .disconnected: return "No device connected."
        case .connecting:   return "Connecting..."
        case .connected(let device): return "Connected to \(device.productName)."
        case .error(let msg): return "Error: \(msg)"
        }
    }

    // MARK: - Actions

    public enum MenuAction: Equatable, Hashable {
        case syncNow
        case cancelSync
        case openApp
        case quit
    }

    public var availableActions: [MenuAction] {
        var actions: [MenuAction] = []

        if case .connected = connection {
            if case .transferring = transfer {
                actions.append(.cancelSync)
            } else {
                actions.append(.syncNow)
            }
        }

        actions.append(.openApp)
        actions.append(.quit)
        return actions
    }

    // MARK: - Last sync

    public var lastSyncFormatted: String? {
        guard let date = lastSyncDate else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
