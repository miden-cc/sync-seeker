import Foundation

public struct Folder: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let path: URL
    public var children: [Folder]
    public var documents: [Document]

    public init(id: UUID = UUID(), name: String, path: URL, children: [Folder] = [], documents: [Document] = []) {
        self.id = id
        self.name = name
        self.path = path
        self.children = children
        self.documents = documents
    }
}
