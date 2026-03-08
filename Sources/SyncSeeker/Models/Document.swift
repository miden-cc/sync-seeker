import Foundation
import CoreTransferable

public enum FileType: String, Codable, CaseIterable, Hashable, Sendable {
    case pdf
    case markdown
    case plainText
    case richText
    case unknown
}

public struct Document: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let path: URL
    public let size: Int64
    public let modifiedDate: Date
    public let fileType: FileType
    public var tags: [String]
    public var summary: String?

    public init(id: UUID = UUID(), name: String, path: URL, size: Int64, modifiedDate: Date, fileType: FileType, tags: [String] = [], summary: String? = nil) {
        self.id = id
        self.name = name
        self.path = path
        self.size = size
        self.modifiedDate = modifiedDate
        self.fileType = fileType
        self.tags = tags
        self.summary = summary
    }
}

@available(macOS 13.0, iOS 16.0, *)
extension Document: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .data) { document in
            SentTransferredFile(document.path)
        }
    }
}
