import Foundation
import Testing
@testable import SyncSeeker

@Suite("ShortcutActions")
struct ShortcutActionsTests {

    // MARK: - SyncAction

    @Test("SyncAction.perform with no diff returns zero result")
    func syncActionNoDiff() {
        let action = SyncAction()
        let source = TestFixtures.manifest(entries: [TestFixtures.fileA])
        let dest = TestFixtures.manifest(root: TestFixtures.destURL, entries: [TestFixtures.fileA])

        let result = action.planSync(source: source, destination: dest)

        #expect(result.addedCount == 0)
        #expect(result.modifiedCount == 0)
        #expect(result.deletedCount == 0)
        #expect(result.totalTransferBytes == 0)
        #expect(result.description.contains("up to date") || result.description.contains("No"))
    }

    @Test("SyncAction.perform with changes reports correct counts")
    func syncActionWithChanges() {
        let action = SyncAction()
        let source = TestFixtures.manifest(entries: [TestFixtures.fileA, TestFixtures.fileB, TestFixtures.fileC])
        let dest = TestFixtures.manifest(root: TestFixtures.destURL, entries: [TestFixtures.fileA])

        let result = action.planSync(source: source, destination: dest)

        #expect(result.addedCount == 2)
        #expect(result.modifiedCount == 0)
        #expect(result.deletedCount == 0)
        #expect(result.totalTransferBytes > 0)
    }

    @Test("SyncAction.perform with modified file reports modification")
    func syncActionModified() {
        let action = SyncAction()
        let source = TestFixtures.manifest(entries: [TestFixtures.fileBModified])
        let dest = TestFixtures.manifest(root: TestFixtures.destURL, entries: [TestFixtures.fileB])

        let result = action.planSync(source: source, destination: dest)

        #expect(result.modifiedCount == 1)
    }

    @Test("SyncAction description is human-readable for Shortcuts")
    func syncActionDescription() {
        let action = SyncAction()
        let source = TestFixtures.manifest(entries: [TestFixtures.fileA, TestFixtures.fileB])
        let dest = TestFixtures.manifest(root: TestFixtures.destURL, entries: [])

        let result = action.planSync(source: source, destination: dest)

        #expect(result.description.contains("2"))
        #expect(result.description.lowercased().contains("add") || result.description.lowercased().contains("file"))
    }

    // MARK: - SearchAction

    @Test("SearchAction splits query into keywords")
    func searchActionKeywords() {
        let action = SearchAction()
        let result = action.buildQuery(text: "NDA contract 2025", fileType: nil, tag: nil)

        #expect(result.keywords == ["NDA", "contract", "2025"])
    }

    @Test("SearchAction applies file type filter")
    func searchActionFileType() {
        let action = SearchAction()
        let result = action.buildQuery(text: "invoice", fileType: "pdf", tag: nil)

        #expect(result.fileTypes == [.pdf])
    }

    @Test("SearchAction applies tag filter")
    func searchActionTag() {
        let action = SearchAction()
        let result = action.buildQuery(text: "report", fileType: nil, tag: "finance")

        #expect(result.tags == ["finance"])
    }

    @Test("SearchAction with all params combines them")
    func searchActionAll() {
        let action = SearchAction()
        let result = action.buildQuery(text: "plan", fileType: "markdown", tag: "project")

        #expect(result.keywords == ["plan"])
        #expect(result.fileTypes == [.markdown])
        #expect(result.tags == ["project"])
    }

    // MARK: - SummarizeAction

    @Test("SummarizeAction.formatResult produces Shortcuts-friendly string")
    func summarizeActionFormat() {
        let action = SummarizeAction()
        let summary = DocumentSummary(
            documentId: UUID(),
            shortSummary: "This is an NDA between two companies.",
            extractedKeywords: ["NDA", "confidential"],
            suggestedTags: ["legal"]
        )

        let text = action.formatResult(summary)

        #expect(text.contains("NDA between two companies"))
        #expect(text.contains("NDA") && text.contains("confidential"))
        #expect(text.contains("legal"))
    }

    @Test("SummarizeAction.formatResult with empty summary")
    func summarizeActionEmpty() {
        let action = SummarizeAction()
        let summary = DocumentSummary(
            documentId: UUID(),
            shortSummary: "",
            extractedKeywords: [],
            suggestedTags: []
        )

        let text = action.formatResult(summary)
        #expect(text.contains("No summary"))
    }
}
