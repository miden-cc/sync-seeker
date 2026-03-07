import Foundation
import Testing
@testable import SyncSeeker

@Suite("SyncFrameEncoder")
struct SyncFrameEncoderTests {

    // MARK: - Transfer header

    @Test("Header starts with magic SYNC")
    func headerMagic() {
        let data = SyncFrameEncoder.encodeHeader(fileCount: 3)
        let magic = String(data: data.prefix(4), encoding: .utf8)
        #expect(magic == "SYNC")
    }

    @Test("Header encodes file count as little-endian uint32")
    func headerFileCount() {
        let data = SyncFrameEncoder.encodeHeader(fileCount: 7)
        #expect(readLE(UInt32.self, from: data, at: 4) == 7)
    }

    @Test("Header is exactly 12 bytes")
    func headerSize() {
        let data = SyncFrameEncoder.encodeHeader(fileCount: 0)
        #expect(data.count == 12)
    }

    @Test("Header encodes delete count as little-endian uint32")
    func headerDeleteCount() {
        let data = SyncFrameEncoder.encodeHeader(fileCount: 0, deleteCount: 3)
        #expect(readLE(UInt32.self, from: data, at: 8) == 3)
    }

    @Test("encodeDeletion encodes path length and UTF-8 bytes")
    func deletionFrame() {
        let path = "old/file.txt"
        let frame = SyncFrameEncoder.encodeDeletion(path: path)
        let pathLen = readLE(UInt32.self, from: frame, at: 0)
        #expect(Int(pathLen) == path.utf8.count)
        let pathBytes = frame.subdata(in: 4..<(4 + Int(pathLen)))
        #expect(String(data: pathBytes, encoding: .utf8) == path)
    }

    // MARK: - Done sentinel

    @Test("Done frame is exactly 4 bytes DONE")
    func doneFrame() {
        let data = SyncFrameEncoder.encodeDone()
        #expect(data.count == 4)
        #expect(String(data: data, encoding: .utf8) == "DONE")
    }

    // MARK: - File frame structure

    @Test("File frame contains correct path length prefix")
    func fileFramePathLength() throws {
        let entry = makeEntry(path: "docs/plan.pdf")
        let frame = try SyncFrameEncoder.encodeFile(entry: entry, fileData: Data([1, 2, 3]), xattrs: [:])

        let pathLen = readLE(UInt32.self, from: frame, at: 0)
        #expect(Int(pathLen) == "docs/plan.pdf".utf8.count)
    }

    @Test("File frame contains correct path UTF-8 bytes")
    func fileFramePath() throws {
        let path = "notes/hello 日本語.txt"
        let entry = makeEntry(path: path)
        let frame = try SyncFrameEncoder.encodeFile(entry: entry, fileData: Data(), xattrs: [:])

        let pathLen = Int(readLE(UInt32.self, from: frame, at: 0))
        let pathBytes = frame.subdata(in: 4..<(4 + pathLen))
        #expect(String(data: pathBytes, encoding: .utf8) == path)
    }

    @Test("File frame contains correct size as uint64")
    func fileFrameSize() throws {
        let entry = makeEntry(path: "a.txt", size: 98765)
        let frame = try SyncFrameEncoder.encodeFile(entry: entry, fileData: Data(count: Int(98765)), xattrs: [:])

        let pathLen = Int(readLE(UInt32.self, from: frame, at: 0))
        let sizeOffset = 4 + pathLen
        let size = readLE(UInt64.self, from: frame, at: sizeOffset)
        #expect(size == 98765)
    }

    @Test("File frame contains file data after size field")
    func fileFrameData() throws {
        let payload = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let entry = makeEntry(path: "x.bin", size: 4)
        let frame = try SyncFrameEncoder.encodeFile(entry: entry, fileData: payload, xattrs: [:])

        let pathLen = Int(readLE(UInt32.self, from: frame, at: 0))
        let dataOffset = 4 + pathLen + 8  // pathLen prefix + path + uint64 size
        let extracted = frame.subdata(in: dataOffset..<(dataOffset + 4))
        #expect(extracted == payload)
    }

    @Test("File frame with no xattrs has zero xattr length")
    func fileFrameNoXattrs() throws {
        let data = Data([0xFF])
        let entry = makeEntry(path: "f.txt", size: 1)
        let frame = try SyncFrameEncoder.encodeFile(entry: entry, fileData: data, xattrs: [:])

        let pathLen = Int(readLE(UInt32.self, from: frame, at: 0))
        let xattrLenOffset = 4 + pathLen + 8 + 1  // after file data
        let xattrLen = readLE(UInt32.self, from: frame, at: xattrLenOffset)
        #expect(xattrLen == 0)
    }

    @Test("File frame xattrs are plist-encoded")
    func fileFrameWithXattrs() throws {
        let xattrs: [String: Data] = [
            "com.apple.metadata:_kMDItemUserTags": try! PropertyListSerialization.data(
                fromPropertyList: ["legal", "important"], format: .binary, options: 0
            )
        ]
        let fileData = Data([0x01])
        let entry = makeEntry(path: "contract.pdf", size: 1, hasXattr: true)
        let frame = try SyncFrameEncoder.encodeFile(entry: entry, fileData: fileData, xattrs: xattrs)

        let pathLen = Int(readLE(UInt32.self, from: frame, at: 0))
        let xattrLenOffset = 4 + pathLen + 8 + 1
        let xattrLen = Int(readLE(UInt32.self, from: frame, at: xattrLenOffset))

        #expect(xattrLen > 0)

        let xattrPlist = frame.subdata(in: (xattrLenOffset + 4)..<(xattrLenOffset + 4 + xattrLen))
        let decoded = try PropertyListSerialization.propertyList(from: xattrPlist, format: nil) as? [String: Data]
        #expect(decoded != nil)
        #expect(decoded?.keys.contains("com.apple.metadata:_kMDItemUserTags") == true)
    }

    // MARK: - Full stream

    @Test("Full transfer stream has correct structure")
    func fullStream() throws {
        let entries = [
            makeEntry(path: "a.txt", size: 3),
            makeEntry(path: "b.txt", size: 5),
        ]
        let files = [Data([1, 2, 3]), Data([1, 2, 3, 4, 5])]

        var stream = SyncFrameEncoder.encodeHeader(fileCount: 2)
        for (entry, file) in zip(entries, files) {
            stream += try SyncFrameEncoder.encodeFile(entry: entry, fileData: file, xattrs: [:])
        }
        stream += SyncFrameEncoder.encodeDone()

        #expect(stream.prefix(4) == "SYNC".data(using: .utf8)!)
        #expect(stream.suffix(4) == "DONE".data(using: .utf8)!)
    }

    // MARK: - Helper

    private func makeEntry(path: String, size: Int64 = 0, hasXattr: Bool = false) -> ManifestEntry {
        ManifestEntry(relativePath: path, size: size, modifiedDate: Date(), sha256: "test", hasXattr: hasXattr)
    }

    /// アラインメントを気にせずリトルエンディアン整数を安全に読む。
    private func readLE<T: FixedWidthInteger>(_ type: T.Type, from data: Data, at offset: Int) -> T {
        var value = T(0)
        withUnsafeMutableBytes(of: &value) { dst in
            data.copyBytes(to: dst, from: offset..<(offset + MemoryLayout<T>.size))
        }
        return T(littleEndian: value)
    }
}
