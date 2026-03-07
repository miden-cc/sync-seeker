import Foundation
import Testing
@testable import SyncSeeker

/// FoundationModelsIntelligenceService の単体テスト。
/// macOS 26 未満ではスタブが動くため、ガード節で分岐する。
@Suite("FoundationModelsIntelligenceService")
struct FoundationModelsServiceTests {

    // MARK: - スタブ動作（全 OS で実行）

    @Test("Stub throws modelUnavailable on unsupported platforms")
    func stubThrowsModelUnavailable() async {
        guard !FoundationModelsIntelligenceService.isAppleIntelligenceAvailable else { return }
        let service = FoundationModelsIntelligenceService()
        await #expect(throws: IntelligenceError.modelUnavailable) {
            try await service.summarize(text: "hello", maxLength: 100)
        }
    }

    // MARK: - 入力バリデーション（macOS 26+ で実行）

    @Test("summarize with empty text throws emptyInput")
    func summarizeEmpty() async {
        guard #available(macOS 26, iOS 26, *) else { return }
        let service = FoundationModelsIntelligenceService(availabilityOverride: true)
        await #expect(throws: IntelligenceError.emptyInput) {
            try await service.summarize(text: "", maxLength: 200)
        }
    }

    @Test("extractKeywords with empty text throws emptyInput")
    func extractKeywordsEmpty() async {
        guard #available(macOS 26, iOS 26, *) else { return }
        let service = FoundationModelsIntelligenceService(availabilityOverride: true)
        await #expect(throws: IntelligenceError.emptyInput) {
            try await service.extractKeywords(from: "", maxCount: 5)
        }
    }

    @Test("suggestTags with empty text throws emptyInput")
    func suggestTagsEmpty() async {
        guard #available(macOS 26, iOS 26, *) else { return }
        let service = FoundationModelsIntelligenceService(availabilityOverride: true)
        await #expect(throws: IntelligenceError.emptyInput) {
            try await service.suggestTags(for: "")
        }
    }

    @Test("translateQuery with empty string throws emptyInput")
    func translateQueryEmpty() async {
        guard #available(macOS 26, iOS 26, *) else { return }
        let service = FoundationModelsIntelligenceService(availabilityOverride: true)
        await #expect(throws: IntelligenceError.emptyInput) {
            try await service.translateQuery("")
        }
    }

    @Test("availabilityOverride false throws modelUnavailable")
    func availabilityOverrideFalse() async {
        guard #available(macOS 26, iOS 26, *) else { return }
        let service = FoundationModelsIntelligenceService(availabilityOverride: false)
        await #expect(throws: IntelligenceError.modelUnavailable) {
            try await service.summarize(text: "hello", maxLength: 100)
        }
    }

    // MARK: - ライブテスト（Apple Intelligence 必須）

    @Test("summarize returns non-empty string within maxLength",
          .enabled(if: FoundationModelsIntelligenceService.isAppleIntelligenceAvailable))
    func summarizeLive() async throws {
        guard #available(macOS 26, iOS 26, *) else { return }
        let service = FoundationModelsIntelligenceService()
        let text = """
        This non-disclosure agreement is entered into between Company A and Company B.
        The Receiving Party agrees to keep all confidential information strictly private.
        """
        let summary = try await service.summarize(text: text, maxLength: 200)
        #expect(!summary.isEmpty)
        #expect(summary.count <= 200)
    }

    @Test("extractKeywords returns at most maxCount items",
          .enabled(if: FoundationModelsIntelligenceService.isAppleIntelligenceAvailable))
    func extractKeywordsLive() async throws {
        guard #available(macOS 26, iOS 26, *) else { return }
        let service = FoundationModelsIntelligenceService()
        let keywords = try await service.extractKeywords(
            from: "A non-disclosure agreement for software consulting services.",
            maxCount: 3
        )
        #expect(keywords.count <= 3)
        #expect(!keywords.isEmpty)
    }

    @Test("suggestTags returns non-empty array",
          .enabled(if: FoundationModelsIntelligenceService.isAppleIntelligenceAvailable))
    func suggestTagsLive() async throws {
        guard #available(macOS 26, iOS 26, *) else { return }
        let service = FoundationModelsIntelligenceService()
        let tags = try await service.suggestTags(
            for: "Invoice #1234 for consulting services, due March 31. Amount: ¥150,000."
        )
        #expect(!tags.isEmpty)
    }

    @Test("translateQuery returns non-empty SearchQuery",
          .enabled(if: FoundationModelsIntelligenceService.isAppleIntelligenceAvailable))
    func translateQueryLive() async throws {
        guard #available(macOS 26, iOS 26, *) else { return }
        let service = FoundationModelsIntelligenceService()
        let query = try await service.translateQuery("A社とのNDA契約書のPDF")
        #expect(!query.isEmpty)
    }
}
