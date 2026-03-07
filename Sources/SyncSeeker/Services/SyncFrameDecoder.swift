import Foundation

// MARK: - Error

public enum SyncFrameDecoderError: Error {
    case invalidMagic
    case dataTooShort(expected: Int, got: Int)
    case invalidPath
    case invalidXattrPlist
}

// MARK: - Decoded types

public struct SyncHeader {
    public let fileCount: Int
    public let deletionCount: Int
}

public struct DecodedFileFrame {
    public let relativePath: String
    public let fileData: Data
    public let xattrs: [String: Data]
}

public struct DecodedStream {
    public let files: [DecodedFileFrame]
    public let deletions: [String]
}

// MARK: - Decoder

/// `SyncFrameEncoder` が生成したワイヤーフォーマットをデコードする（iPad 側レシーバー用）。
public enum SyncFrameDecoder {

    // MARK: - Header

    public static func decodeHeader(from data: Data) throws -> SyncHeader {
        guard data.count >= 4 else {
            throw SyncFrameDecoderError.dataTooShort(expected: 12, got: data.count)
        }
        let magic = data.prefix(4)
        guard magic == Data("SYNC".utf8) else {
            throw SyncFrameDecoderError.invalidMagic
        }
        guard data.count >= 12 else {
            throw SyncFrameDecoderError.dataTooShort(expected: 12, got: data.count)
        }
        let count = readUInt32(from: data, at: 4)
        let deletionCount = readUInt32(from: data, at: 8)
        return SyncHeader(fileCount: Int(count), deletionCount: Int(deletionCount))
    }

    // MARK: - Done sentinel

    public static func isDoneSentinel(_ data: Data) -> Bool {
        data.count >= 4 && data.prefix(4) == Data("DONE".utf8)
    }

    // MARK: - File frame

    /// 1 ファイル分のフレームをデコードする。
    public static func decodeFileFrame(from data: Data) throws -> DecodedFileFrame {
        var offset = 0

        // path_length (4) + path
        let pathLen = Int(try read32(data, &offset))
        let path = try readString(data, at: &offset, length: pathLen)

        // file_size (8) + file_data
        let fileSize = Int(try read64(data, &offset))
        let fileData = try readBytes(data, at: &offset, count: fileSize)

        // xattr_length (4) + xattr_plist
        let xattrLen = Int(try read32(data, &offset))
        let xattrs: [String: Data]
        if xattrLen > 0 {
            let xattrData = try readBytes(data, at: &offset, count: xattrLen)
            guard let plist = try? PropertyListSerialization.propertyList(from: xattrData, format: nil) as? [String: Data] else {
                throw SyncFrameDecoderError.invalidXattrPlist
            }
            xattrs = plist
        } else {
            xattrs = [:]
        }

        return DecodedFileFrame(relativePath: path, fileData: fileData, xattrs: xattrs)
    }

    // MARK: - Full stream

    /// ヘッダー + ファイルフレーム群 + DELT フレーム群 + DONE のストリーム全体をデコードする。
    public static func decodeStream(_ data: Data) throws -> DecodedStream {
        let header = try decodeHeader(from: data)
        var offset = 12  // header size
        var files: [DecodedFileFrame] = []

        for _ in 0..<header.fileCount {
            let remaining = data.subdata(in: offset..<data.count)
            let frame = try decodeFileFrame(from: remaining)

            // Advance offset by the consumed bytes
            let pathLen = Int(readUInt32(from: data, at: offset))
            let fileSize = Int(readUInt64(from: data, at: offset + 4 + pathLen))
            let xattrLen = Int(readUInt32(from: data, at: offset + 4 + pathLen + 8 + fileSize))
            offset += 4 + pathLen + 8 + fileSize + 4 + xattrLen

            files.append(frame)
        }

        var deletions: [String] = []
        for _ in 0..<header.deletionCount {
            let pathLen = Int(try read32(data, &offset))
            let path = try readString(data, at: &offset, length: pathLen)
            deletions.append(path)
        }

        return DecodedStream(files: files, deletions: deletions)
    }

    // MARK: - Private helpers

    private static func read32(_ data: Data, _ offset: inout Int) throws -> UInt32 {
        guard offset + 4 <= data.count else {
            throw SyncFrameDecoderError.dataTooShort(expected: offset + 4, got: data.count)
        }
        let value = readUInt32(from: data, at: offset)
        offset += 4
        return value
    }

    private static func read64(_ data: Data, _ offset: inout Int) throws -> UInt64 {
        guard offset + 8 <= data.count else {
            throw SyncFrameDecoderError.dataTooShort(expected: offset + 8, got: data.count)
        }
        let value = readUInt64(from: data, at: offset)
        offset += 8
        return value
    }

    private static func readString(_ data: Data, at offset: inout Int, length: Int) throws -> String {
        guard offset + length <= data.count else {
            throw SyncFrameDecoderError.dataTooShort(expected: offset + length, got: data.count)
        }
        let bytes = data.subdata(in: offset..<(offset + length))
        offset += length
        guard let str = String(data: bytes, encoding: .utf8) else {
            throw SyncFrameDecoderError.invalidPath
        }
        return str
    }

    private static func readBytes(_ data: Data, at offset: inout Int, count: Int) throws -> Data {
        guard offset + count <= data.count else {
            throw SyncFrameDecoderError.dataTooShort(expected: offset + count, got: data.count)
        }
        let bytes = data.subdata(in: offset..<(offset + count))
        offset += count
        return bytes
    }

    private static func readUInt32(from data: Data, at offset: Int) -> UInt32 {
        var value: UInt32 = 0
        _ = withUnsafeMutableBytes(of: &value) { dst in
            data.copyBytes(to: dst, from: offset..<(offset + 4))
        }
        return UInt32(littleEndian: value)
    }

    private static func readUInt64(from data: Data, at offset: Int) -> UInt64 {
        var value: UInt64 = 0
        _ = withUnsafeMutableBytes(of: &value) { dst in
            data.copyBytes(to: dst, from: offset..<(offset + 8))
        }
        return UInt64(littleEndian: value)
    }
}
