import Foundation
@testable import SyncSeeker

final class MockIntelligenceService: IntelligenceServiceProtocol {
    var summarizeResult: String = "Mock summary of the document."
    var keywordsResult: [String] = ["contract", "NDA"]
    var tagsResult: [String] = ["legal", "important"]
    var queryResult: SearchQuery = SearchQuery(keywords: ["contract"], dateRange: nil, fileTypes: [.pdf], tags: [])

    var summarizeError: Error?
    var keywordsError: Error?
    var queryError: Error?
    var tagsError: Error?

    var summarizeCalled = false
    var extractKeywordsCalled = false
    var translateQueryCalled = false
    var suggestTagsCalled = false
    var lastSummarizeText: String?
    var lastQueryInput: String?

    func summarize(text: String, maxLength: Int) async throws -> String {
        summarizeCalled = true
        lastSummarizeText = text
        if let error = summarizeError { throw error }
        return String(summarizeResult.prefix(maxLength))
    }

    func extractKeywords(from text: String, maxCount: Int) async throws -> [String] {
        extractKeywordsCalled = true
        if let error = keywordsError { throw error }
        return Array(keywordsResult.prefix(maxCount))
    }

    func translateQuery(_ naturalLanguage: String) async throws -> SearchQuery {
        translateQueryCalled = true
        lastQueryInput = naturalLanguage
        if let error = queryError { throw error }
        return queryResult
    }

    func suggestTags(for text: String) async throws -> [String] {
        suggestTagsCalled = true
        if let error = tagsError { throw error }
        return tagsResult
    }
}
