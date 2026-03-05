import Foundation
import Testing
@testable import SyncSeeker

@Suite("SearchQuery")
struct SearchQueryTests {

    @Test("Empty query")
    func emptyQuery() {
        let query = SearchQuery(keywords: [], dateRange: nil, fileTypes: [], tags: [])
        #expect(query.isEmpty)
    }

    @Test("Query with keywords is not empty")
    func withKeywords() {
        let query = SearchQuery(keywords: ["contract"], dateRange: nil, fileTypes: [], tags: [])
        #expect(!query.isEmpty)
    }

    @Test("Query with date range is not empty")
    func withDateRange() {
        let range = SearchQuery.DateRange(from: Date(), to: nil)
        let query = SearchQuery(keywords: [], dateRange: range, fileTypes: [], tags: [])
        #expect(!query.isEmpty)
    }

    @Test("Query with file types is not empty")
    func withFileTypes() {
        let query = SearchQuery(keywords: [], dateRange: nil, fileTypes: [.pdf], tags: [])
        #expect(!query.isEmpty)
    }

    @Test("Query with tags is not empty")
    func withTags() {
        let query = SearchQuery(keywords: [], dateRange: nil, fileTypes: [], tags: ["NDA"])
        #expect(!query.isEmpty)
    }

    @Test("Query equality")
    func equality() {
        let a = SearchQuery(keywords: ["x"], dateRange: nil, fileTypes: [.pdf], tags: ["y"])
        let b = SearchQuery(keywords: ["x"], dateRange: nil, fileTypes: [.pdf], tags: ["y"])
        #expect(a == b)
    }
}
