import Foundation

protocol IntelligenceServiceProtocol {
    func summarize(text: String, maxLength: Int) async throws -> String
    func extractKeywords(from text: String, maxCount: Int) async throws -> [String]
    func translateQuery(_ naturalLanguage: String) async throws -> SearchQuery
    func suggestTags(for text: String) async throws -> [String]
}

enum IntelligenceError: Error, Equatable {
    case modelUnavailable
    case textTooShort
    case emptyInput
    case generationFailed(String)
}
