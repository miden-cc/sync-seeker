import Foundation

public struct DiffResult: Equatable {
    let added: [ManifestEntry]
    let modified: [ManifestEntry]
    let deleted: [ManifestEntry]

    var totalChanges: Int {
        added.count + modified.count + deleted.count
    }

    var isEmpty: Bool {
        added.isEmpty && modified.isEmpty && deleted.isEmpty
    }

    var totalTransferSize: Int64 {
        (added + modified).reduce(0) { $0 + $1.size }
    }
}
