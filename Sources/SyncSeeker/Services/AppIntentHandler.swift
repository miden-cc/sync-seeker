import Foundation

/// App Intents / Siri のビジネスロジック層。
/// 実際の `AppIntent` プロトコル宣言は Xcode ターゲットで行い、
/// perform() からこのハンドラーを呼び出す設計とする。

struct AppIntentHandler {

    // MARK: - Search Intent

    func handleSearchIntent(query: String, fileType: String?) -> SearchQuery {
        let keywords = query
            .split(separator: " ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let fileTypes: [FileType]
        if let ft = fileType {
            fileTypes = [FileType(rawValue: ft) ?? .unknown]
        } else {
            fileTypes = []
        }

        return SearchQuery(
            keywords: keywords,
            dateRange: nil,
            fileTypes: fileTypes,
            tags: []
        )
    }

    // MARK: - Summarize Intent

    struct SummarizeRequest {
        let documentName: String
        let documentPath: String
    }

    func prepareSummarizeIntent(documentName: String, documentPath: String) -> SummarizeRequest {
        SummarizeRequest(documentName: documentName, documentPath: documentPath)
    }

    // MARK: - Sync Status Intent

    struct SyncStatus {
        let isConnected: Bool
        let deviceName: String?
        let displayText: String
    }

    func syncStatus(from state: ConnectionState) -> SyncStatus {
        switch state {
        case .disconnected:
            return SyncStatus(isConnected: false, deviceName: nil, displayText: "No device connected.")
        case .connecting:
            return SyncStatus(isConnected: false, deviceName: nil, displayText: "Connecting to device...")
        case .connected(let device):
            return SyncStatus(
                isConnected: true,
                deviceName: device.productName,
                displayText: "Connected to \(device.productName)."
            )
        case .error(let message):
            return SyncStatus(isConnected: false, deviceName: nil, displayText: "Error: \(message)")
        }
    }

    // MARK: - Format helpers

    func formatTransferResult(fileCount: Int, totalBytes: Int64) -> String {
        guard fileCount > 0 else { return "No files to transfer." }
        let fileWord = fileCount == 1 ? "1 file" : "\(fileCount) files"
        return "Transferred \(fileWord) (\(formatBytes(totalBytes)))."
    }

    func formatBytes(_ bytes: Int64) -> String {
        let units: [(String, Double)] = [("GB", 1e9), ("MB", 1e6), ("KB", 1e3)]
        for (unit, threshold) in units {
            if Double(bytes) >= threshold {
                let value = Double(bytes) / threshold
                return String(format: "%.1f %@", value, unit)
            }
        }
        return "\(bytes) B"
    }
}
