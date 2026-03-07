import Foundation

// MARK: - Models

/// 双方向同期の計画。Mac → iPad と iPad → Mac の両方の差分 + コンフリクトを含む。
struct BidirectionalSyncPlan {
    let toIPad: DiffResult
    let toMac: DiffResult
    let conflicts: [SyncConflict]
}

/// 両デバイスで同じファイルが異なる内容に変更された場合のコンフリクト。
struct SyncConflict: Equatable {
    let path: String
    let macEntry: ManifestEntry
    let iPadEntry: ManifestEntry
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
struct BidirectionalSyncEngine {

    /// 双方のマニフェストと最終同期時刻から同期計画を生成する。
    /// - Parameters:
    ///   - mac: Mac 側のファイルマニフェスト
    ///   - iPad: iPad 側のファイルマニフェスト
    ///   - lastSync: 前回の同期完了時刻（初回同期の場合は nil）
    func computeSyncPlan(mac: FileManifest, iPad: FileManifest, lastSync: Date?) -> BidirectionalSyncPlan {
        let macPaths  = mac.filePaths
        let iPadPaths = iPad.filePaths

        let macOnly   = macPaths.subtracting(iPadPaths)
        let iPadOnly  = iPadPaths.subtracting(macPaths)
        let common    = macPaths.intersection(iPadPaths)

        // Mac-only files → push to iPad
        let addToIPad = macOnly.compactMap { mac.entry(forPath: $0) }
            .sorted { $0.relativePath < $1.relativePath }

        // iPad-only files → pull to Mac (if newer than lastSync or no lastSync)
        let addToMac = iPadOnly.compactMap { iPad.entry(forPath: $0) }
            .sorted { $0.relativePath < $1.relativePath }

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
                deleted: []  // 双方向同期で削除は別途慎重に扱う
            ),
            toMac: DiffResult(
                added: addToMac,
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
