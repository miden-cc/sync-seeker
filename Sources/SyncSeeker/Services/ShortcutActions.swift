import Foundation

// MARK: - SyncAction

/// Shortcuts「SyncSeeker で同期」アクションのロジック。
struct SyncAction {

    struct SyncPlan {
        let addedCount: Int
        let modifiedCount: Int
        let deletedCount: Int
        let totalTransferBytes: Int64
        let description: String
    }

    private let diffEngine = DiffEngine()

    /// ソース・デスティネーションの差分を計算し、Shortcuts に返す計画を作成する。
    func planSync(source: FileManifest, destination: FileManifest) -> SyncPlan {
        let diff = diffEngine.computeDiff(source: source, destination: destination)

        if diff.isEmpty {
            return SyncPlan(
                addedCount: 0, modifiedCount: 0, deletedCount: 0,
                totalTransferBytes: 0,
                description: "Already up to date. No files to sync."
            )
        }

        let parts: [String] = [
            diff.added.isEmpty ? nil : "\(diff.added.count) added",
            diff.modified.isEmpty ? nil : "\(diff.modified.count) modified",
            diff.deleted.isEmpty ? nil : "\(diff.deleted.count) deleted",
        ].compactMap { $0 }

        return SyncPlan(
            addedCount: diff.added.count,
            modifiedCount: diff.modified.count,
            deletedCount: diff.deleted.count,
            totalTransferBytes: diff.totalTransferSize,
            description: "Sync plan: \(parts.joined(separator: ", ")) file(s)."
        )
    }
}

// MARK: - SearchAction

/// Shortcuts「SyncSeeker で検索」アクションのロジック。
struct SearchAction {

    /// Shortcuts パラメータから SearchQuery を構築する。
    func buildQuery(text: String, fileType: String?, tag: String?) -> SearchQuery {
        let keywords = text
            .split(separator: " ")
            .map { String($0) }
            .filter { !$0.isEmpty }

        let fileTypes: [FileType]
        if let ft = fileType {
            fileTypes = [FileType(rawValue: ft) ?? .unknown]
        } else {
            fileTypes = []
        }

        let tags: [String]
        if let t = tag, !t.isEmpty {
            tags = [t]
        } else {
            tags = []
        }

        return SearchQuery(keywords: keywords, dateRange: nil, fileTypes: fileTypes, tags: tags)
    }
}

// MARK: - SummarizeAction

/// Shortcuts「SyncSeeker で要約」アクションのロジック。
struct SummarizeAction {

    /// DocumentSummary を Shortcuts 向けテキストに整形する。
    func formatResult(_ summary: DocumentSummary) -> String {
        if summary.shortSummary.isEmpty && summary.extractedKeywords.isEmpty && summary.suggestedTags.isEmpty {
            return "No summary available for this document."
        }

        var lines: [String] = []

        if !summary.shortSummary.isEmpty {
            lines.append("Summary: \(summary.shortSummary)")
        }
        if !summary.extractedKeywords.isEmpty {
            lines.append("Keywords: \(summary.extractedKeywords.joined(separator: ", "))")
        }
        if !summary.suggestedTags.isEmpty {
            lines.append("Tags: \(summary.suggestedTags.joined(separator: ", "))")
        }

        return lines.joined(separator: "\n")
    }
}
