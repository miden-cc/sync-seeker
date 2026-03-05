import Foundation

struct DocumentSummary: Equatable {
    let documentId: UUID
    let shortSummary: String
    let extractedKeywords: [String]
    let suggestedTags: [String]
}
