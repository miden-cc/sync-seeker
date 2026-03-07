import Foundation
import Testing
@testable import SyncSeeker

@Suite("XattrIO")
struct XattrIOTests {

    // MARK: - readAll

    @Test("readAll returns empty dict when file has no xattrs")
    func readAllEmpty() throws {
        let tmp = makeTempFile()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let result = XattrIO.readAll(at: tmp)
        #expect(result.isEmpty)
    }

    @Test("readAll returns written xattr key-value")
    func readAllAfterSet() throws {
        let tmp = makeTempFile()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let value = Data("hello".utf8)
        setxattr(tmp.path, "user.test.key", (value as NSData).bytes, value.count, 0, 0)

        let result = XattrIO.readAll(at: tmp)
        #expect(result["user.test.key"] == value)
    }

    @Test("readAll returns all keys when multiple xattrs exist")
    func readAllMultipleKeys() throws {
        let tmp = makeTempFile()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let v1 = Data("v1".utf8)
        let v2 = Data("v2".utf8)
        setxattr(tmp.path, "user.key1", (v1 as NSData).bytes, v1.count, 0, 0)
        setxattr(tmp.path, "user.key2", (v2 as NSData).bytes, v2.count, 0, 0)

        let result = XattrIO.readAll(at: tmp)
        #expect(result.count == 2)
        #expect(result["user.key1"] == v1)
        #expect(result["user.key2"] == v2)
    }

    @Test("readAll returns empty for non-existent path")
    func readAllNonExistent() {
        let result = XattrIO.readAll(at: URL(fileURLWithPath: "/tmp/no_file_\(UUID().uuidString)"))
        #expect(result.isEmpty)
    }

    // MARK: - writeAll

    @Test("writeAll sets xattrs readable by getxattr")
    func writeAllSetsXattrs() throws {
        let tmp = makeTempFile()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let xattrs: [String: Data] = [
            "user.sync.tag": Data("important".utf8),
            "user.sync.note": Data("review".utf8),
        ]
        XattrIO.writeAll(xattrs, to: tmp)

        // 低レベル API で直接確認
        for (key, expected) in xattrs {
            let len = getxattr(tmp.path, key, nil, 0, 0, 0)
            #expect(len == expected.count)

            var buf = Data(count: len)
            buf.withUnsafeMutableBytes { getxattr(tmp.path, key, $0.baseAddress, len, 0, 0) }
            #expect(buf == expected)
        }
    }

    @Test("writeAll with empty dict is a no-op")
    func writeAllEmpty() throws {
        let tmp = makeTempFile()
        defer { try? FileManager.default.removeItem(at: tmp) }

        XattrIO.writeAll([:], to: tmp)
        #expect(XattrIO.readAll(at: tmp).isEmpty)
    }

    // MARK: - Roundtrip

    @Test("readAll after writeAll roundtrips all key-value pairs")
    func roundtrip() throws {
        let tmp = makeTempFile()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let xattrs: [String: Data] = [
            "com.apple.metadata:_kMDItemUserTags": try tagPlist(["work", "urgent"]),
            "user.sync.checksum": Data("abc123".utf8),
        ]
        XattrIO.writeAll(xattrs, to: tmp)
        let result = XattrIO.readAll(at: tmp)

        #expect(result["user.sync.checksum"] == Data("abc123".utf8))
        #expect(result.keys.contains("com.apple.metadata:_kMDItemUserTags"))
    }

    // MARK: - Helpers

    private func makeTempFile() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        return url
    }

    private func tagPlist(_ tags: [String]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: tags, format: .binary, options: 0)
    }
}
