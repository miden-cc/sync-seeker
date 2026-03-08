import Foundation

public struct ManifestEntry: Equatable, Codable, Sendable {
    public let relativePath: String
    public let size: Int64
    public let modifiedDate: Date
    public let sha256: String
    public let hasXattr: Bool
}
