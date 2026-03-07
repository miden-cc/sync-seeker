import Foundation

/// Widget 用データプロバイダー。
/// WidgetKit の `TimelineProvider` からこのクラスのメソッドを呼び出して
/// `TimelineEntry` を構築する設計。

struct WidgetDataProvider {

    // MARK: - Recent Documents

    struct RecentDocumentEntry {
        let id: UUID
        let name: String
        let fileType: FileType
        let modifiedDate: Date
        let summary: String?
    }

    /// 最新の更新日順にドキュメントを返す（Widget 表示用）。
    func recentDocuments(from documents: [Document], limit: Int) -> [RecentDocumentEntry] {
        documents
            .sorted { $0.modifiedDate > $1.modifiedDate }
            .prefix(limit)
            .map { doc in
                RecentDocumentEntry(
                    id: doc.id,
                    name: doc.name,
                    fileType: doc.fileType,
                    modifiedDate: doc.modifiedDate,
                    summary: doc.summary
                )
            }
    }

    // MARK: - Sync Status

    struct SyncStatusEntry {
        let isConnected: Bool
        let deviceName: String?
        let lastSyncFormatted: String?
    }

    /// 現在の接続状態と最終同期時刻から Widget 表示用エントリを生成する。
    func syncStatusEntry(state: ConnectionState, lastSyncDate: Date?) -> SyncStatusEntry {
        let isConnected: Bool
        let deviceName: String?

        switch state {
        case .connected(let device):
            isConnected = true
            deviceName = device.productName
        default:
            isConnected = false
            deviceName = nil
        }

        let formatted: String?
        if let date = lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            formatted = formatter.localizedString(for: date, relativeTo: Date())
        } else {
            formatted = nil
        }

        return SyncStatusEntry(
            isConnected: isConnected,
            deviceName: deviceName,
            lastSyncFormatted: formatted
        )
    }
}
