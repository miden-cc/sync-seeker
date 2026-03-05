import Foundation

protocol AnnotationServiceProtocol {
    func readTags(at path: URL) throws -> [String]
    func writeTags(_ tags: [String], to path: URL) throws
    func readFinderComment(at path: URL) throws -> String?
    func writeFinderComment(_ comment: String, to path: URL) throws
}
