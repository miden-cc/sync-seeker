import Foundation
import Testing
@testable import SyncSeeker

@Suite("ManifestBuilder")
struct ManifestBuilderTests {

    let builder = ManifestBuilder()

    func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sync-seeker-manifest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("Build manifest from directory with files")
    func buildFromDirectory() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        try "hello".data(using: .utf8)!.write(to: dir.appendingPathComponent("a.txt"))
        try "world".data(using: .utf8)!.write(to: dir.appendingPathComponent("b.md"))

        let manifest = try builder.buildManifest(at: dir)

        #expect(manifest.entries.count == 2)
        #expect(manifest.filePaths.contains("a.txt"))
        #expect(manifest.filePaths.contains("b.md"))
    }

    @Test("SHA256 hash is consistent for same content")
    func consistentHash() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let content = "deterministic content"
        try content.data(using: .utf8)!.write(to: dir.appendingPathComponent("file.txt"))

        let m1 = try builder.buildManifest(at: dir)
        let m2 = try builder.buildManifest(at: dir)

        #expect(m1.entries.first?.sha256 == m2.entries.first?.sha256)
    }

    @Test("Different content produces different hash")
    func differentHash() throws {
        let dir1 = try makeTempDir()
        let dir2 = try makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: dir1)
            try? FileManager.default.removeItem(at: dir2)
        }

        try "content A".data(using: .utf8)!.write(to: dir1.appendingPathComponent("file.txt"))
        try "content B".data(using: .utf8)!.write(to: dir2.appendingPathComponent("file.txt"))

        let m1 = try builder.buildManifest(at: dir1)
        let m2 = try builder.buildManifest(at: dir2)

        #expect(m1.entries.first?.sha256 != m2.entries.first?.sha256)
    }

    @Test("Empty directory produces empty manifest")
    func emptyDirectory() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let manifest = try builder.buildManifest(at: dir)

        #expect(manifest.entries.isEmpty)
    }

    @Test("Subdirectory files use relative paths")
    func subdirectoryPaths() throws {
        let dir = try makeTempDir()
        let sub = dir.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try "nested".data(using: .utf8)!.write(to: sub.appendingPathComponent("deep.txt"))

        let manifest = try builder.buildManifest(at: dir)

        #expect(manifest.entries.count == 1)
        #expect(manifest.entries.first?.relativePath == "sub/deep.txt")
    }

    @Test("Detects xattr presence")
    func xattrDetection() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("tagged.txt")
        try "data".data(using: .utf8)!.write(to: file)

        let resolvedPath = file.standardizedFileURL.resolvingSymlinksInPath().path
        let value = "test".data(using: .utf8)!
        value.withUnsafeBytes { buffer in
            _ = setxattr(resolvedPath, "com.test.attr", buffer.baseAddress, value.count, 0, 0)
        }

        let manifest = try builder.buildManifest(at: dir)

        #expect(manifest.entries.first?.hasXattr == true)
    }

    @Test("Entries are sorted by relativePath")
    func sortedEntries() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        try "c".data(using: .utf8)!.write(to: dir.appendingPathComponent("z.txt"))
        try "a".data(using: .utf8)!.write(to: dir.appendingPathComponent("a.txt"))
        try "b".data(using: .utf8)!.write(to: dir.appendingPathComponent("m.txt"))

        let manifest = try builder.buildManifest(at: dir)
        let paths = manifest.entries.map(\.relativePath)

        #expect(paths == paths.sorted())
    }
}
