import Testing
import Foundation
@testable import SyncSeeker

@Suite("Annotation Service (xattr)")
struct AnnotationServiceTests {

    let service = XattrAnnotationService()

    func makeTempFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sync-seeker-test-\(UUID().uuidString).txt")
        FileManager.default.createFile(atPath: url.path, contents: "test content".data(using: .utf8))
        return url
    }

    // MARK: - Tags

    @Test("Write and read tags")
    func writeAndReadTags() throws {
        let file = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: file) }

        try service.writeTags(["contract", "important"], to: file)
        let tags = try service.readTags(at: file)

        #expect(Set(tags) == Set(["contract", "important"]))
    }

    @Test("Read tags from untagged file returns empty")
    func readTagsEmpty() throws {
        let file = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: file) }

        let tags = try service.readTags(at: file)
        #expect(tags.isEmpty)
    }

    @Test("Overwrite tags replaces previous")
    func overwriteTags() throws {
        let file = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: file) }

        try service.writeTags(["old-tag"], to: file)
        try service.writeTags(["new-tag"], to: file)
        let tags = try service.readTags(at: file)

        #expect(tags == ["new-tag"])
    }

    @Test("Write empty tags clears all")
    func writeEmptyTags() throws {
        let file = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: file) }

        try service.writeTags(["something"], to: file)
        try service.writeTags([], to: file)
        let tags = try service.readTags(at: file)

        #expect(tags.isEmpty)
    }

    // MARK: - Finder Comment

    @Test("Write and read Finder comment")
    func writeAndReadComment() throws {
        let file = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: file) }

        let comment = "AI summary: This document discusses contract terms."
        try service.writeFinderComment(comment, to: file)
        let result = try service.readFinderComment(at: file)

        #expect(result == comment)
    }

    @Test("Read comment from uncommented file returns nil")
    func readCommentEmpty() throws {
        let file = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: file) }

        let result = try service.readFinderComment(at: file)
        #expect(result == nil)
    }

    @Test("Overwrite Finder comment replaces previous")
    func overwriteComment() throws {
        let file = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: file) }

        try service.writeFinderComment("old comment", to: file)
        try service.writeFinderComment("new comment", to: file)
        let result = try service.readFinderComment(at: file)

        #expect(result == "new comment")
    }
}
