import Foundation

public struct ManifestEntry: Equatable, Codable, Sendable {
    let relativePath: String
    let size: Int64
    let modifiedDate: Date
    let sha256: String
    let hasXattr: Bool
}
