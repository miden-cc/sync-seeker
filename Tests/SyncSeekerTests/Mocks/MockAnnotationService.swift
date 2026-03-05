import Foundation
@testable import SyncSeeker

final class MockAnnotationService: AnnotationServiceProtocol {
    var storedTags: [URL: [String]] = [:]
    var storedComments: [URL: String] = [:]
    var writeTagsCalled = false
    var writeCommentCalled = false
    var writeError: Error?

    func readTags(at path: URL) throws -> [String] {
        storedTags[path] ?? []
    }

    func writeTags(_ tags: [String], to path: URL) throws {
        writeTagsCalled = true
        if let error = writeError { throw error }
        storedTags[path] = tags
    }

    func readFinderComment(at path: URL) throws -> String? {
        storedComments[path]
    }

    func writeFinderComment(_ comment: String, to path: URL) throws {
        writeCommentCalled = true
        if let error = writeError { throw error }
        storedComments[path] = comment
    }
}
