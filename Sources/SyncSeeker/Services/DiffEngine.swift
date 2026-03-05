import Foundation

struct DiffEngine {

    func computeDiff(source: FileManifest, destination: FileManifest) -> DiffResult {
        let sourcePaths = source.filePaths
        let destPaths = destination.filePaths

        let addedPaths = sourcePaths.subtracting(destPaths)
        let deletedPaths = destPaths.subtracting(sourcePaths)
        let commonPaths = sourcePaths.intersection(destPaths)

        let added = addedPaths.compactMap { source.entry(forPath: $0) }
        let deleted = deletedPaths.compactMap { destination.entry(forPath: $0) }

        let modified = commonPaths.compactMap { path -> ManifestEntry? in
            guard let srcEntry = source.entry(forPath: path),
                  let dstEntry = destination.entry(forPath: path) else { return nil }
            if srcEntry.sha256 != dstEntry.sha256 {
                return srcEntry
            }
            return nil
        }

        return DiffResult(
            added: added.sorted { $0.relativePath < $1.relativePath },
            modified: modified.sorted { $0.relativePath < $1.relativePath },
            deleted: deleted.sorted { $0.relativePath < $1.relativePath }
        )
    }
}
