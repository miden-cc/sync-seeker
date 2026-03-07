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
            let hashString = hash.hexString

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

fileprivate extension SHA256.Digest {
    private static let hexTable: [UInt8] = [
        0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39,
        0x61, 0x62, 0x63, 0x64, 0x65, 0x66
    ]

    var hexString: String {
        return String(unsafeUninitializedCapacity: Self.byteCount * 2) { buffer in
            var index = 0
            for byte in self {
                buffer[index] = Self.hexTable[Int(byte >> 4)]
                index += 1
                buffer[index] = Self.hexTable[Int(byte & 0x0F)]
                index += 1
            }
            return Self.byteCount * 2
        }
    }
}
