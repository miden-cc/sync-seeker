import Foundation

/// ファイルの拡張属性（xattr）を一括読み書きするユーティリティ。
/// SyncFrameEncoder/Decoder の xattrs フィールドと対応する。
public enum XattrIO {

    /// iPad への同期対象外とするシステム内部 xattr キー。
    /// macOS が自動付与するが iPad では意味を持たないもの。
    public static let excludedKeys: Set<String> = [
        "com.apple.provenance",
        "com.apple.quarantine",
        "com.apple.lastuseddate#PS",
        "com.apple.rootless",
    ]

    /// ファイルのすべての xattr を `[key: value]` で返す。
    /// `excludedKeys` に含まれるシステム内部キーは除外する。
    /// 読み取れない場合や xattr がない場合は空辞書を返す（エラーを投げない）。
    public static func readAll(at path: URL) -> [String: Data] {
        let filePath = path.path

        let listSize = listxattr(filePath, nil, 0, 0)
        guard listSize > 0 else { return [:] }

        var keysBuf = [CChar](repeating: 0, count: listSize)
        guard listxattr(filePath, &keysBuf, listSize, 0) >= 0 else { return [:] }

        // null 区切りのキーリストを String 配列に変換
        let keys = Data(bytes: keysBuf, count: listSize)
            .split(separator: 0)
            .compactMap { String(data: $0, encoding: .utf8) }
            .filter { !excludedKeys.contains($0) }

        var result: [String: Data] = [:]
        for key in keys {
            if let value = readValue(key: key, from: filePath) {
                result[key] = value
            }
        }
        return result
    }

    /// `xattrs` の内容をファイルに書き込む。書き込みに失敗したキーは無視する。
    public static func writeAll(_ xattrs: [String: Data], to path: URL) {
        let filePath = path.path
        for (key, value) in xattrs {
            _ = value.withUnsafeBytes { ptr in
                setxattr(filePath, key, ptr.baseAddress, value.count, 0, 0)
            }
        }
    }

    // MARK: - Private

    private static func readValue(key: String, from filePath: String) -> Data? {
        let len = getxattr(filePath, key, nil, 0, 0, 0)
        guard len >= 0 else { return nil }
        var data = Data(count: len)
        let result = data.withUnsafeMutableBytes { ptr in
            getxattr(filePath, key, ptr.baseAddress, len, 0, 0)
        }
        return result >= 0 ? data : nil
    }
}
