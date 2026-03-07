import Foundation

/// LLM レスポンスのパース処理をまとめたユーティリティ（Apple Intelligence 不要、完全テスト可能）。
enum IntelligenceResponseParser {

    // MARK: - Keywords / Tags

    /// カンマ区切りのキーワード文字列を配列に変換する。
    static func parseKeywords(_ response: String, max: Int) -> [String] {
        let tokens = response
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Array(tokens.prefix(max))
    }

    // MARK: - SearchQuery

    struct SearchQueryJSON: Decodable {
        let keywords:  [String]
        let fileTypes: [String]
        let tags:      [String]
        let dateFrom:  String?
        let dateTo:    String?
    }

    /// LLM の JSON レスポンスを `SearchQuery` に変換する。
    /// コードフェンスや余分なテキストを除去してから解析する。
    static func parseSearchQuery(fromJSON raw: String) throws -> SearchQuery {
        // コードフェンス除去 → JSON ブロック抽出 → パース
        let fenced   = stripCodeFence(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonStr  = extractFirstJSON(from: fenced) ?? fenced

        guard let data = jsonStr.data(using: .utf8) else {
            throw IntelligenceError.generationFailed("Cannot convert response to Data")
        }

        let parsed: SearchQueryJSON
        do {
            parsed = try JSONDecoder().decode(SearchQueryJSON.self, from: data)
        } catch {
            throw IntelligenceError.generationFailed("JSON parse failed: \(error.localizedDescription)")
        }

        let fileTypes: [FileType] = parsed.fileTypes.map { FileType(rawValue: $0) ?? .unknown }
        let uniqueFileTypes = fileTypes.reduce(into: [FileType]()) { acc, ft in
            if !acc.contains(ft) { acc.append(ft) }
        }

        let dateRange: SearchQuery.DateRange? = {
            let from = parsed.dateFrom.flatMap { parseISO8601($0) }
            let to   = parsed.dateTo.flatMap   { parseISO8601($0) }
            guard from != nil || to != nil else { return nil }
            return SearchQuery.DateRange(from: from, to: to)
        }()

        return SearchQuery(
            keywords:  parsed.keywords,
            dateRange: dateRange,
            fileTypes: uniqueFileTypes,
            tags:      parsed.tags
        )
    }

    // MARK: - Misc

    static func truncate(_ text: String, to maxLength: Int) -> String {
        String(text.prefix(maxLength))
    }

    /// テキスト中から最初の `{...}` JSON オブジェクトを抽出する。
    static func extractFirstJSON(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }
        var depth = 0
        var end = start
        for idx in text[start...].indices {
            switch text[idx] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { end = idx; break }
            default: break
            }
            if depth == 0 { break }
        }
        guard depth == 0 else { return nil }
        return String(text[start...end])
    }

    // MARK: - Private

    private static func stripCodeFence(_ text: String) -> String {
        let fencePattern = #"^```(?:json)?\s*\n?([\s\S]*?)\n?```\s*$"#
        guard let regex = try? NSRegularExpression(pattern: fencePattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text)
        else { return text }
        return String(text[range])
    }

    private static func parseISO8601(_ string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
