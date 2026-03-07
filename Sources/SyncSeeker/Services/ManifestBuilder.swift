import Foundation
import CryptoKit

public struct ManifestBuilder {

    public init() {}

    public func buildManifest(at rootPath: URL) throws -> FileManifest {
        let fm = FileManager.default
        let resolvedRoot = rootPath.standardizedFileURL.resolvingSymlinksInPath()
        let rootPrefix = resolvedRoot.path + "/"

        let enumerator = fm.enumerator(
            at: resolvedRoot,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var entries: [ManifestEntry] = []

        while let fileURL = enumerator?.nextObject() as? URL {
            let resolved = fileURL.standardizedFileURL.resolvingSymlinksInPath()
            let values = try resolved.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
            guard values.isDirectory != true else { continue }

            let relativePath = resolved.path.replacingOccurrences(of: rootPrefix, with: "")
            let data = try Data(contentsOf: resolved)
            let hash = SHA256.hash(data: data)
            let hashString = hash.map { String(format: "%02x", $0) }.joined()

            let xattrCount = listxattr(resolved.path, nil, 0, 0)

            entries.append(ManifestEntry(
                relativePath: relativePath,
                size: Int64(values.fileSize ?? 0),
                modifiedDate: values.contentModificationDate ?? Date(),
                sha256: hashString,
                hasXattr: xattrCount > 0
            ))
        }

        return FileManifest(
            rootPath: resolvedRoot,
            entries: entries.sorted { $0.relativePath < $1.relativePath },
            createdAt: Date()
        )
    }
}
