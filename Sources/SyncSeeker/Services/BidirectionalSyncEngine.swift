import Foundation

// MARK: - Models

/// 双方向同期の計画。Mac → iPad と iPad → Mac の両方の差分 + コンフリクトを含む。
public struct BidirectionalSyncPlan {
    public let toIPad: DiffResult
    public let toMac: DiffResult
    public let conflicts: [SyncConflict]
}

/// 両デバイスで同じファイルが異なる内容に変更された場合のコンフリクト。
public struct SyncConflict: Equatable {
    public let path: String
    public let macEntry: ManifestEntry
    public let iPadEntry: ManifestEntry
}

/// コンフリクト解決戦略。
enum ConflictStrategy {
    case macWins
    case iPadWins
    case newestWins
}

/// コンフリクト解決結果。
struct ConflictResolution {
    enum Direction { case toMac, toIPad }
    let direction: Direction
    let entry: ManifestEntry
}

// MARK: - Engine

/// Mac ↔ iPad 双方向同期のマージロジック。
public struct BidirectionalSyncEngine {

    public init() {}

    /// 双方のマニフェストと最終同期時刻から同期計画を生成する。
    /// - Parameters:
    ///   - mac: Mac 側のファイルマニフェスト
    ///   - iPad: iPad 側のファイルマニフェスト
    ///   - lastSync: 前回の同期完了時刻（初回同期の場合は nil）
    public func computeSyncPlan(mac: FileManifest, iPad: FileManifest, lastSync: Date?) -> BidirectionalSyncPlan {
        let macPaths  = mac.filePaths
        let iPadPaths = iPad.filePaths

        let macOnly   = macPaths.subtracting(iPadPaths)
        let iPadOnly  = iPadPaths.subtracting(macPaths)
        let common    = macPaths.intersection(iPadPaths)

        // Mac-only files → push to iPad
        let addToIPad = macOnly.compactMap { mac.entry(forPath: $0) }
            .sorted { $0.relativePath < $1.relativePath }

        // iPad-only files
        var addToMac: [ManifestEntry] = []
        var delToIPad: [ManifestEntry] = []

        for p in iPadOnly {
            guard let entry = iPad.entry(forPath: p) else { continue }
            // If it's newer than lastSync (or no lastSync), iPad created it -> pull to Mac
            if lastSync == nil || entry.modifiedDate > lastSync! {
                addToMac.append(entry)
            } else {
                // Older than lastSync -> Mac deleted/renamed it -> delete from iPad
                delToIPad.append(entry)
            }
        }

        // Common files: compare hashes and modification dates
        var modToIPad: [ManifestEntry] = []
        var modToMac:  [ManifestEntry] = []
        var conflicts: [SyncConflict]  = []

        for path in common {
            guard let macEntry  = mac.entry(forPath: path),
                  let iPadEntry = iPad.entry(forPath: path)
            else { continue }

            // Identical content → skip
            if macEntry.sha256 == iPadEntry.sha256 { continue }

            let macModified  = lastSync.map { macEntry.modifiedDate > $0 } ?? true
            let iPadModified = lastSync.map { iPadEntry.modifiedDate > $0 } ?? true

            switch (macModified, iPadModified) {
            case (true, false):
                modToIPad.append(macEntry)
            case (false, true):
                modToMac.append(iPadEntry)
            case (true, true):
                conflicts.append(SyncConflict(path: path, macEntry: macEntry, iPadEntry: iPadEntry))
            case (false, false):
                // Neither modified since last sync but different hashes — rare edge case.
                // Default: newer wins.
                if macEntry.modifiedDate >= iPadEntry.modifiedDate {
                    modToIPad.append(macEntry)
                } else {
                    modToMac.append(iPadEntry)
                }
            }
        }

        return BidirectionalSyncPlan(
            toIPad: DiffResult(
                added: addToIPad,
                modified: modToIPad.sorted { $0.relativePath < $1.relativePath },
                deleted: delToIPad.sorted { $0.relativePath < $1.relativePath }
            ),
            toMac: DiffResult(
                added: addToMac.sorted { $0.relativePath < $1.relativePath },
                modified: modToMac.sorted { $0.relativePath < $1.relativePath },
                deleted: []
            ),
            conflicts: conflicts
        )
    }

    /// コンフリクトを解決する。
    func resolve(_ conflict: SyncConflict, strategy: ConflictStrategy) -> ConflictResolution {
        switch strategy {
        case .macWins:
            return ConflictResolution(direction: .toIPad, entry: conflict.macEntry)
        case .iPadWins:
            return ConflictResolution(direction: .toMac, entry: conflict.iPadEntry)
        case .newestWins:
            if conflict.macEntry.modifiedDate >= conflict.iPadEntry.modifiedDate {
                return ConflictResolution(direction: .toIPad, entry: conflict.macEntry)
            } else {
                return ConflictResolution(direction: .toMac, entry: conflict.iPadEntry)
            }
        }
    }
}
