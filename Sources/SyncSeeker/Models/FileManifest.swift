import Foundation

struct FileManifest: Equatable {
    let rootPath: URL
    let entries: [ManifestEntry]
    let createdAt: Date

    func entry(forPath path: String) -> ManifestEntry? {
        entries.first { $0.relativePath == path }
    }

    var filePaths: Set<String> {
        Set(entries.map(\.relativePath))
    }
}
