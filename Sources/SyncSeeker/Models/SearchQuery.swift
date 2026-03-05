import Foundation

struct SearchQuery: Equatable {
    let keywords: [String]
    let dateRange: DateRange?
    let fileTypes: [FileType]
    let tags: [String]

    struct DateRange: Equatable {
        let from: Date?
        let to: Date?
    }

    var isEmpty: Bool {
        keywords.isEmpty && dateRange == nil && fileTypes.isEmpty && tags.isEmpty
    }
}
