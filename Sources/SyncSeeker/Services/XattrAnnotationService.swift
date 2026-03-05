import Foundation

public struct XattrAnnotationService: AnnotationServiceProtocol {

    private let tagKey = "com.apple.metadata:_kMDItemUserTags"
    private let commentKey = "com.apple.metadata:kMDItemFinderComment"

    public init() {}

    public func readTags(at path: URL) throws -> [String] {
        guard let data = try readXattr(key: tagKey, from: path) else {
            return []
        }
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String] else {
            return []
        }
        return plist
    }

    public func writeTags(_ tags: [String], to path: URL) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: tags, format: .binary, options: 0)
        try writeXattr(key: tagKey, data: data, to: path)
    }

    public func readFinderComment(at path: URL) throws -> String? {
        guard let data = try readXattr(key: commentKey, from: path) else {
            return nil
        }
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? String else {
            return nil
        }
        return plist
    }

    public func writeFinderComment(_ comment: String, to path: URL) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: comment, format: .binary, options: 0)
        try writeXattr(key: commentKey, data: data, to: path)
    }

    private func readXattr(key: String, from path: URL) throws -> Data? {
        let length = getxattr(path.path, key, nil, 0, 0, 0)
        guard length >= 0 else {
            if errno == ENOATTR { return nil }
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes { buffer in
            getxattr(path.path, key, buffer.baseAddress, length, 0, 0)
        }
        guard result >= 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        return data
    }

    private func writeXattr(key: String, data: Data, to path: URL) throws {
        let result = data.withUnsafeBytes { buffer in
            setxattr(path.path, key, buffer.baseAddress, data.count, 0, 0)
        }
        guard result == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
    }
}

private let ENOATTR: Int32 = 93
