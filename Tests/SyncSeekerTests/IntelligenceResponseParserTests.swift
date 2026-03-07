import Foundation
import Testing
@testable import SyncSeeker

/// IntelligenceResponseParser の純粋ロジック（Apple Intelligence 不要）をテスト。
@Suite("IntelligenceResponseParser")
struct IntelligenceResponseParserTests {

    // MARK: - parseKeywords

    @Test("Parse comma-separated keywords")
    func parseKeywords() {
        let result = IntelligenceResponseParser.parseKeywords("contract, NDA, agreement", max: 10)
        #expect(result == ["contract", "NDA", "agreement"])
    }

    @Test("Parse keywords trims whitespace")
    func parseKeywordsTrimmed() {
        let result = IntelligenceResponseParser.parseKeywords("  legal ,  finance , important  ", max: 10)
        #expect(result == ["legal", "finance", "important"])
    }

    @Test("Parse keywords respects max count")
    func parseKeywordsMax() {
        let result = IntelligenceResponseParser.parseKeywords("a, b, c, d, e", max: 3)
        #expect(result.count == 3)
        #expect(result == ["a", "b", "c"])
    }

    @Test("Parse empty string returns empty array")
    func parseKeywordsEmpty() {
        let result = IntelligenceResponseParser.parseKeywords("", max: 5)
        #expect(result.isEmpty)
    }

    @Test("Parse keywords filters blank tokens")
    func parseKeywordsFiltersBlanks() {
        let result = IntelligenceResponseParser.parseKeywords("apple, , , banana", max: 10)
        #expect(result == ["apple", "banana"])
    }

    // MARK: - parseSearchQueryJSON

    @Test("Parse full JSON produces correct SearchQuery")
    func parseFullJSON() throws {
        let json = """
        {
          "keywords": ["contract", "NDA"],
          "fileTypes": ["pdf"],
          "tags": ["legal"],
          "dateFrom": null,
          "dateTo": null
        }
        """
        let query = try IntelligenceResponseParser.parseSearchQuery(fromJSON: json)
        #expect(query.keywords == ["contract", "NDA"])
        #expect(query.fileTypes == [.pdf])
        #expect(query.tags == ["legal"])
        #expect(query.dateRange == nil)
    }

    @Test("Parse JSON with date range")
    func parseJSONWithDates() throws {
        let json = """
        {
          "keywords": ["receipt"],
          "fileTypes": [],
          "tags": [],
          "dateFrom": "2025-01-01T00:00:00Z",
          "dateTo": null
        }
        """
        let query = try IntelligenceResponseParser.parseSearchQuery(fromJSON: json)
        #expect(query.dateRange?.from != nil)
        #expect(query.dateRange?.to == nil)
        #expect(query.keywords == ["receipt"])
    }

    @Test("Parse JSON with unknown file type falls back to .unknown")
    func parseJSONUnknownFileType() throws {
        let json = """
        {"keywords": [], "fileTypes": ["docx"], "tags": [], "dateFrom": null, "dateTo": null}
        """
        let query = try IntelligenceResponseParser.parseSearchQuery(fromJSON: json)
        #expect(query.fileTypes == [.unknown])
    }

    @Test("Parse JSON with empty arrays produces empty SearchQuery fields")
    func parseJSONEmpty() throws {
        let json = """
        {"keywords": [], "fileTypes": [], "tags": [], "dateFrom": null, "dateTo": null}
        """
        let query = try IntelligenceResponseParser.parseSearchQuery(fromJSON: json)
        #expect(query.isEmpty)
    }

    @Test("Parse invalid JSON throws generationFailed error")
    func parseInvalidJSON() {
        #expect(throws: IntelligenceError.self) {
            try IntelligenceResponseParser.parseSearchQuery(fromJSON: "not json at all")
        }
    }

    @Test("Parse JSON with markdown code fence strips fences")
    func parseJSONWithCodeFence() throws {
        let json = """
        ```json
        {"keywords": ["invoice"], "fileTypes": ["pdf"], "tags": [], "dateFrom": null, "dateTo": null}
        ```
        """
        let query = try IntelligenceResponseParser.parseSearchQuery(fromJSON: json)
        #expect(query.keywords == ["invoice"])
    }

    // MARK: - truncate

    @Test("Truncate to maxLength")
    func truncate() {
        let result = IntelligenceResponseParser.truncate("Hello World", to: 5)
        #expect(result == "Hello")
    }

    @Test("Truncate shorter text unchanged")
    func truncateShort() {
        let result = IntelligenceResponseParser.truncate("Hi", to: 100)
        #expect(result == "Hi")
    }
}
