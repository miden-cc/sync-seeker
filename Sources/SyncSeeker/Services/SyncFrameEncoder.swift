import Foundation

/// Mac → iPad 転送のワイヤーフォーマットエンコーダ。
///
/// ストリーム構造:
/// ```
/// HEADER  = magic(4:"SYNC") + file_count(4:UInt32 LE) + delt_count(4:UInt32 LE)
/// FILE    = path_length(4:UInt32 LE) + path(UTF-8)
///           + file_size(8:UInt64 LE) + file_data
///           + xattr_length(4:UInt32 LE) + xattr_plist([String:Data])
/// DELT    = path_length(4:UInt32 LE) + path(UTF-8)
/// DONE    = "DONE"(4)
/// ```
enum SyncFrameEncoder {

    // MARK: - Header / Done

    static func encodeHeader(fileCount: Int, deleteCount: Int = 0) -> Data {
        var data = Data(capacity: 12)
        data += "SYNC".data(using: .utf8)!
        data += uint32LE(UInt32(fileCount))
        data += uint32LE(UInt32(deleteCount))
        return data
    }

    static func encodeDone() -> Data {
        return "DONE".data(using: .utf8)!
    }

    // MARK: - Deletion frame

    /// 削除対象のパスをエンコードする。
    static func encodeDeletion(path: String) -> Data {
        let pathBytes = Data(path.utf8)
        var frame = Data(capacity: 4 + pathBytes.count)
        frame += uint32LE(UInt32(pathBytes.count))
        frame += pathBytes
        return frame
    }

    // MARK: - File frame

    /// 1ファイル分のフレームを構築する。
    /// - Parameters:
    ///   - entry: マニフェストエントリ（パス・サイズ情報）
    ///   - fileData: ファイルの生バイト列
    ///   - xattrs: キー → 値 の xattr マップ（空可）
    static func encodeFile(
        entry: ManifestEntry,
        fileData: Data,
        xattrs: [String: Data]
    ) throws -> Data {
        let pathBytes = Data(entry.relativePath.utf8)

        let xattrPlist: Data
        if xattrs.isEmpty {
            xattrPlist = Data()
        } else {
            xattrPlist = try PropertyListSerialization.data(
                fromPropertyList: xattrs, format: .binary, options: 0
            )
        }

        var frame = Data(capacity: 4 + pathBytes.count + 8 + fileData.count + 4 + xattrPlist.count)
        frame += uint32LE(UInt32(pathBytes.count))
        frame += pathBytes
        frame += uint64LE(UInt64(fileData.count))
        frame += fileData
        frame += uint32LE(UInt32(xattrPlist.count))
        frame += xattrPlist
        return frame
    }

    // MARK: - Utilities

    private static func uint32LE(_ v: UInt32) -> Data {
        var n = v.littleEndian
        return Data(bytes: &n, count: 4)
    }

    private static func uint64LE(_ v: UInt64) -> Data {
        var n = v.littleEndian
        return Data(bytes: &n, count: 8)
    }
}
