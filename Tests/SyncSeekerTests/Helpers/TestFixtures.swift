import Foundation
@testable import SyncSeeker

enum TestFixtures {
    static let now = Date()

    static let fileA = ManifestEntry(relativePath: "docs/readme.md", size: 100, modifiedDate: now, sha256: "aaa111", hasXattr: false)
    static let fileB = ManifestEntry(relativePath: "docs/plan.pdf", size: 5000, modifiedDate: now, sha256: "bbb222", hasXattr: true)
    static let fileC = ManifestEntry(relativePath: "notes/todo.txt", size: 50, modifiedDate: now, sha256: "ccc333", hasXattr: false)

    static let fileBModified = ManifestEntry(relativePath: "docs/plan.pdf", size: 5200, modifiedDate: now, sha256: "bbb999", hasXattr: true)

    static let rootURL = URL(fileURLWithPath: "/tmp/sync-source")
    static let destURL = URL(fileURLWithPath: "/tmp/sync-dest")

    static func manifest(root: URL = rootURL, entries: [ManifestEntry]) -> FileManifest {
        FileManifest(rootPath: root, entries: entries, createdAt: now)
    }
}
