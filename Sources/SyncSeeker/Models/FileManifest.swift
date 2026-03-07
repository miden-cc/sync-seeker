import Foundation

public struct FileManifest: Equatable, Codable {
    public let rootPath: URL
    public let entries: [ManifestEntry]
    public let createdAt: Date

    public func entry(forPath path: String) -> ManifestEntry? {
        entries.first { $0.relativePath == path }
    }

    public var filePaths: Set<String> {
        Set(entries.map(\.relativePath))
    }
}
