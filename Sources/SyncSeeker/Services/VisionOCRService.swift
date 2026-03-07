import Foundation
import Vision
import PDFKit
import CoreGraphics

// MARK: - Error

enum OCRError: Error {
    case invalidPDF(URL)
    case renderFailed
    case ocrFailed(String)
}

// MARK: - VisionOCRService

/// Vision フレームワークを使って PDF ページの画像からテキストを OCR 抽出するサービス。
/// PDF の selectable text は PDFKit 経由で取得し、画像 PDF は Vision で補完する。
final class VisionOCRService {

    private let renderScale: CGFloat
    private let recognitionLanguages: [String]

    /// - Parameters:
    ///   - renderScale: PDF ページを画像にレンダリングする際の倍率（デフォルト 2.0 = 144 DPI）。
    ///   - recognitionLanguages: Vision に渡す言語コード。
    init(renderScale: CGFloat = 2.0, recognitionLanguages: [String] = ["en-US", "ja-JP"]) {
        self.renderScale = renderScale
        self.recognitionLanguages = recognitionLanguages
    }

    // MARK: - Public API

    /// PDF ファイル全ページのテキストを抽出して結合して返す。
    func extractText(from pdfURL: URL) async throws -> String {
        guard FileManager.default.fileExists(atPath: pdfURL.path) else {
            throw OCRError.invalidPDF(pdfURL)
        }
        guard let doc = PDFDocument(url: pdfURL) else {
            throw OCRError.invalidPDF(pdfURL)
        }
        guard doc.pageCount > 0 else { return "" }

        var pages: [String] = []
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let text = try await extractText(from: page)
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pages.append(text)
            }
        }
        return pages.joined(separator: "\n\n")
    }

    /// 1 ページのテキストを抽出する。
    /// PDFKit で取得できる selectable text を優先し、空の場合は Vision OCR にフォールバックする。
    func extractText(from page: PDFPage) async throws -> String {
        // PDFKit selectable text（ベクター PDF の場合は高速）
        let nativeText = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !nativeText.isEmpty {
            return nativeText
        }
        // 画像 PDF → Vision OCR
        return try await ocrPage(page)
    }

    // MARK: - Private

    /// ページを CGImage にレンダリングして Vision OCR を実行する。
    private func ocrPage(_ page: PDFPage) async throws -> String {
        guard let image = renderPage(page) else {
            throw OCRError.renderFailed
        }
        return try await withCheckedThrowingContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            let request = VNRecognizeTextRequest { req, error in
                if let error {
                    continuation.resume(throwing: OCRError.ocrFailed(error.localizedDescription))
                    return
                }
                let lines = (req.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string } ?? []
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = recognitionLanguages

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.ocrFailed(error.localizedDescription))
            }
        }
    }

    /// PDF ページを `renderScale` 倍の CGImage に変換する。
    private func renderPage(_ page: PDFPage) -> CGImage? {
        let pageRect = page.bounds(for: .mediaBox)
        let width  = Int(pageRect.width  * renderScale)
        let height = Int(pageRect.height * renderScale)

        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.setFillColor(CGColor(gray: 1.0, alpha: 1.0))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.scaleBy(x: renderScale, y: renderScale)
        page.draw(with: .mediaBox, to: ctx)

        return ctx.makeImage()
    }
}
