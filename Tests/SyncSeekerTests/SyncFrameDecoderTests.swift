import Foundation
import Testing
@testable import SyncSeeker

@Suite("SyncFrameDecoder")
struct SyncFrameDecoderTests {

    // MARK: - Header

    @Test("Decode header extracts magic and file count")
    func decodeHeader() throws {
        let data = SyncFrameEncoder.encodeHeader(fileCount: 3)
        let header = try SyncFrameDecoder.decodeHeader(from: data)

        #expect(header.fileCount == 3)
    }

    @Test("Decode header with invalid magic throws")
    func decodeHeaderBadMagic() {
        var data = Data("BADM".utf8)
        data.append(contentsOf: [0x03, 0x00, 0x00, 0x00])
        #expect(throws: SyncFrameDecoderError.self) {
            try SyncFrameDecoder.decodeHeader(from: data)
        }
    }

    @Test("Decode header with too-short data throws")
    func decodeHeaderTooShort() {
        #expect(throws: SyncFrameDecoderError.self) {
            try SyncFrameDecoder.decodeHeader(from: Data([0x01, 0x02]))
        }
    }

    // MARK: - Done sentinel

    @Test("isDoneSentinel recognizes DONE")
    func isDone() {
        let data = SyncFrameEncoder.encodeDone()
        #expect(SyncFrameDecoder.isDoneSentinel(data))
    }

    @Test("isDoneSentinel rejects non-DONE data")
    func isNotDone() {
        #expect(!SyncFrameDecoder.isDoneSentinel(Data("SYNC".utf8)))
        #expect(!SyncFrameDecoder.isDoneSentinel(Data([0x00, 0x00, 0x00, 0x00])))
    }

    // MARK: - File frame roundtrip

    @Test("Encode then decode single file frame roundtrips correctly")
    func roundtripSingleFile() throws {
        let entry = ManifestEntry(
            relativePath: "docs/readme.md",
            size: 5,
            modifiedDate: Date(),
            sha256: "abc123",
            hasXattr: false
        )
        let fileData = Data("hello".utf8)
        let encoded = try SyncFrameEncoder.encodeFile(entry: entry, fileData: fileData, xattrs: [:])

        let decoded = try SyncFrameDecoder.decodeFileFrame(from: encoded)

        #expect(decoded.relativePath == "docs/readme.md")
        #expect(decoded.fileData == fileData)
        #expect(decoded.xattrs.isEmpty)
    }

    @Test("Roundtrip preserves Unicode path")
    func roundtripUnicodePath() throws {
        let entry = ManifestEntry(
            relativePath: "ドキュメント/契約書.pdf",
            size: 3,
            modifiedDate: Date(),
            sha256: "xyz",
            hasXattr: false
        )
        let encoded = try SyncFrameEncoder.encodeFile(entry: entry, fileData: Data([1, 2, 3]), xattrs: [:])
        let decoded = try SyncFrameDecoder.decodeFileFrame(from: encoded)

        #expect(decoded.relativePath == "ドキュメント/契約書.pdf")
    }

    @Test("Roundtrip with xattrs preserves xattr data")
    func roundtripWithXattrs() throws {
        let tagData = try PropertyListSerialization.data(
            fromPropertyList: ["legal", "NDA"], format: .binary, options: 0
        )
        let xattrs: [String: Data] = ["com.apple.metadata:_kMDItemUserTags": tagData]

        let entry = ManifestEntry(
            relativePath: "contract.pdf",
            size: 1,
            modifiedDate: Date(),
            sha256: "def",
            hasXattr: true
        )
        let encoded = try SyncFrameEncoder.encodeFile(entry: entry, fileData: Data([0xFF]), xattrs: xattrs)
        let decoded = try SyncFrameDecoder.decodeFileFrame(from: encoded)

        #expect(decoded.xattrs.keys.contains("com.apple.metadata:_kMDItemUserTags"))
    }

    @Test("Roundtrip with large file data")
    func roundtripLargeFile() throws {
        let bigData = Data(repeating: 0xAB, count: 100_000)
        let entry = ManifestEntry(
            relativePath: "big.bin",
            size: Int64(bigData.count),
            modifiedDate: Date(),
            sha256: "big",
            hasXattr: false
        )
        let encoded = try SyncFrameEncoder.encodeFile(entry: entry, fileData: bigData, xattrs: [:])
        let decoded = try SyncFrameDecoder.decodeFileFrame(from: encoded)

        #expect(decoded.fileData.count == 100_000)
        #expect(decoded.fileData == bigData)
    }

    // MARK: - Full stream roundtrip

    @Test("Full stream encode-decode roundtrip with multiple files")
    func fullStreamRoundtrip() throws {
        let entries: [(ManifestEntry, Data)] = [
            (ManifestEntry(relativePath: "a.txt", size: 3, modifiedDate: Date(), sha256: "a1", hasXattr: false), Data("aaa".utf8)),
            (ManifestEntry(relativePath: "b.txt", size: 5, modifiedDate: Date(), sha256: "b2", hasXattr: false), Data("bbbbb".utf8)),
        ]

        // Encode full stream
        var stream = SyncFrameEncoder.encodeHeader(fileCount: entries.count)
        for (entry, data) in entries {
            stream += try SyncFrameEncoder.encodeFile(entry: entry, fileData: data, xattrs: [:])
        }
        stream += SyncFrameEncoder.encodeDone()

        // Decode
        let result = try SyncFrameDecoder.decodeStream(stream)
        #expect(result.files.count == 2)
        #expect(result.files[0].relativePath == "a.txt")
        #expect(result.files[0].fileData == Data("aaa".utf8))
        #expect(result.files[1].relativePath == "b.txt")
        #expect(result.files[1].fileData == Data("bbbbb".utf8))
    }
}
