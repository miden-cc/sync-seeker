import Foundation
import Testing
@testable import SyncSeeker

@Suite("IntelligenceViewModel")
struct IntelligenceViewModelTests {

    static let sampleDoc = Document(
        id: UUID(),
        name: "contract.pdf",
        path: URL(fileURLWithPath: "/tmp/contract.pdf"),
        size: 1024,
        modifiedDate: Date(),
        fileType: .pdf,
        tags: []
    )

    static let sampleText = "This is a legal contract between Party A and Party B regarding non-disclosure agreement terms."

    // MARK: - Initial State

    @Test("Initial state has no summary or error")
    func initialState() {
        let intel = MockIntelligenceService()
        let annotation = MockAnnotationService()
        let vm = IntelligenceViewModel(intelligence: intel, annotationService: annotation)

        #expect(vm.lastSummary == nil)
        #expect(vm.lastSearchQuery == nil)
        #expect(vm.lastError == nil)
        #expect(vm.isProcessing == false)
    }

    // MARK: - Summarize

    @Test("Summarize document produces summary with keywords and tags")
    func summarizeSuccess() async {
        let intel = MockIntelligenceService()
        let annotation = MockAnnotationService()
        let vm = IntelligenceViewModel(intelligence: intel, annotationService: annotation)

        await vm.summarizeDocument(Self.sampleDoc, text: Self.sampleText)

        #expect(vm.lastSummary != nil)
        #expect(vm.lastSummary?.documentId == Self.sampleDoc.id)
        #expect(vm.lastSummary?.shortSummary.isEmpty == false)
        #expect(vm.lastSummary?.extractedKeywords == ["contract", "NDA"])
        #expect(vm.lastSummary?.suggestedTags == ["legal", "important"])
        #expect(vm.isProcessing == false)
        #expect(vm.lastError == nil)
    }

    @Test("Summarize calls all intelligence methods")
    func summarizeCallsAll() async {
        let intel = MockIntelligenceService()
        let annotation = MockAnnotationService()
        let vm = IntelligenceViewModel(intelligence: intel, annotationService: annotation)

        await vm.summarizeDocument(Self.sampleDoc, text: Self.sampleText)

        #expect(intel.summarizeCalled)
        #expect(intel.extractKeywordsCalled)
        #expect(intel.suggestTagsCalled)
    }

    @Test("Summarize writes to native annotations")
    func summarizeWritesAnnotations() async {
        let intel = MockIntelligenceService()
        let annotation = MockAnnotationService()
        let vm = IntelligenceViewModel(intelligence: intel, annotationService: annotation)

        await vm.summarizeDocument(Self.sampleDoc, text: Self.sampleText)

        #expect(annotation.writeCommentCalled)
        #expect(annotation.writeTagsCalled)
        #expect(annotation.storedComments[Self.sampleDoc.path] != nil)
        #expect(annotation.storedTags[Self.sampleDoc.path] == ["legal", "important"])
    }

    @Test("Summarize with empty text sets emptyInput error")
    func summarizeEmptyText() async {
        let intel = MockIntelligenceService()
        let annotation = MockAnnotationService()
        let vm = IntelligenceViewModel(intelligence: intel, annotationService: annotation)

        await vm.summarizeDocument(Self.sampleDoc, text: "")

        #expect(vm.lastError == .emptyInput)
        #expect(vm.lastSummary == nil)
    }

    @Test("Summarize handles intelligence error")
    func summarizeError() async {
        let intel = MockIntelligenceService()
        intel.summarizeError = IntelligenceError.modelUnavailable
        let annotation = MockAnnotationService()
        let vm = IntelligenceViewModel(intelligence: intel, annotationService: annotation)

        await vm.summarizeDocument(Self.sampleDoc, text: Self.sampleText)

        #expect(vm.lastError == .modelUnavailable)
        #expect(vm.lastSummary == nil)
        #expect(vm.isProcessing == false)
    }

    // MARK: - Search

    @Test("Search translates natural language to structured query")
    func searchSuccess() async {
        let intel = MockIntelligenceService()
        intel.queryResult = SearchQuery(
            keywords: ["contract", "A社"],
            dateRange: nil,
            fileTypes: [.pdf],
            tags: ["NDA"]
        )
        let annotation = MockAnnotationService()
        let vm = IntelligenceViewModel(intelligence: intel, annotationService: annotation)

        await vm.search(naturalLanguage: "A社との契約書でNDAのもの")

        #expect(intel.translateQueryCalled)
        #expect(intel.lastQueryInput == "A社との契約書でNDAのもの")
        #expect(vm.lastSearchQuery?.keywords == ["contract", "A社"])
        #expect(vm.lastSearchQuery?.fileTypes == [.pdf])
        #expect(vm.lastSearchQuery?.tags == ["NDA"])
        #expect(vm.isProcessing == false)
    }

    @Test("Search with empty query sets emptyInput error")
    func searchEmpty() async {
        let intel = MockIntelligenceService()
        let annotation = MockAnnotationService()
        let vm = IntelligenceViewModel(intelligence: intel, annotationService: annotation)

        await vm.search(naturalLanguage: "")

        #expect(vm.lastError == .emptyInput)
        #expect(vm.lastSearchQuery == nil)
    }

    @Test("Search handles intelligence error")
    func searchError() async {
        let intel = MockIntelligenceService()
        intel.queryError = IntelligenceError.generationFailed("Parse error")
        let annotation = MockAnnotationService()
        let vm = IntelligenceViewModel(intelligence: intel, annotationService: annotation)

        await vm.search(naturalLanguage: "some query")

        #expect(vm.lastError == .generationFailed("Parse error"))
        #expect(vm.lastSearchQuery == nil)
    }

    // MARK: - Search with date range

    @Test("Search query with date range")
    func searchWithDateRange() async {
        let intel = MockIntelligenceService()
        let from = Date(timeIntervalSince1970: 1700000000)
        intel.queryResult = SearchQuery(
            keywords: ["receipt"],
            dateRange: SearchQuery.DateRange(from: from, to: nil),
            fileTypes: [],
            tags: []
        )
        let annotation = MockAnnotationService()
        let vm = IntelligenceViewModel(intelligence: intel, annotationService: annotation)

        await vm.search(naturalLanguage: "去年の領収書")

        #expect(vm.lastSearchQuery?.dateRange?.from == from)
        #expect(vm.lastSearchQuery?.keywords == ["receipt"])
    }
}
