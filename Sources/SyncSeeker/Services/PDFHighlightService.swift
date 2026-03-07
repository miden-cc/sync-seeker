import Foundation
import PDFKit

// MARK: - Model

/// PDF ハイライトアノテーションのデータモデル。
struct PDFHighlight: Equatable {
    let page: Int
    let bounds: CGRect
    let color: HighlightColor
    let content: String

    enum HighlightColor: String, Equatable, Codable {
        case yellow, green, pink

        var cgColor: CGColor {
            switch self {
            case .yellow: return CGColor(red: 1.0, green: 0.95, blue: 0.0, alpha: 0.5)
            case .green:  return CGColor(red: 0.0, green: 0.9,  blue: 0.3, alpha: 0.5)
            case .pink:   return CGColor(red: 1.0, green: 0.4,  blue: 0.6, alpha: 0.5)
            }
        }
    }
}

// MARK: - Error

enum PDFHighlightError: Error {
    case pdfCreationFailed(String)
    case invalidPDF(URL)
    case pageOutOfRange(Int)
    case writeFailed(URL)
}

// MARK: - Protocol

protocol PDFHighlightServiceProtocol {
    func addHighlight(_ highlight: PDFHighlight, to pdfURL: URL) throws
    func readHighlights(from pdfURL: URL) throws -> [PDFHighlight]
    func removeAllHighlights(from pdfURL: URL) throws
}

// MARK: - PDFKit implementation

struct PDFKitHighlightService: PDFHighlightServiceProtocol {

    /// annotation.contents に埋め込む JSON ペイロード。
    /// PDF 標準の /Contents フィールドを使うので round-trip で保持される。
    private struct Payload: Codable {
        let syncseeker: String   // "v1" - アプリ製アノテーションを識別
        let color: PDFHighlight.HighlightColor
        let content: String
    }

    func addHighlight(_ highlight: PDFHighlight, to pdfURL: URL) throws {
        let doc = try loadDocument(at: pdfURL)
        guard let page = doc.page(at: highlight.page) else {
            throw PDFHighlightError.pageOutOfRange(highlight.page)
        }

        let annotation = PDFAnnotation(bounds: highlight.bounds, forType: .highlight, withProperties: nil)
        annotation.color = platformColor(from: highlight.color.cgColor)

        // ペイロードを JSON にして /Contents に格納
        let payload = Payload(syncseeker: "v1", color: highlight.color, content: highlight.content)
        if let json = try? JSONEncoder().encode(payload),
           let str = String(data: json, encoding: .utf8) {
            annotation.contents = str
        }

        page.addAnnotation(annotation)
        try savePDF(doc, to: pdfURL)
    }

    func readHighlights(from pdfURL: URL) throws -> [PDFHighlight] {
        let doc = try loadDocument(at: pdfURL)
        var highlights: [PDFHighlight] = []

        for pageIndex in 0..<doc.pageCount {
            guard let page = doc.page(at: pageIndex) else { continue }
            for annotation in page.annotations
            where annotation.type == "Highlight" {
                guard
                    let contentsStr = annotation.contents,
                    let data = contentsStr.data(using: .utf8),
                    let payload = try? JSONDecoder().decode(Payload.self, from: data),
                    payload.syncseeker == "v1"
                else { continue }

                highlights.append(PDFHighlight(
                    page: pageIndex,
                    bounds: annotation.bounds,
                    color: payload.color,
                    content: payload.content
                ))
            }
        }

        return highlights
    }

    func removeAllHighlights(from pdfURL: URL) throws {
        let doc = try loadDocument(at: pdfURL)
        var modified = false

        for pageIndex in 0..<doc.pageCount {
            guard let page = doc.page(at: pageIndex) else { continue }
            for annotation in page.annotations
            where annotation.type == "Highlight" {
                // SyncSeeker が付けたアノテーションのみ削除
                if let contents = annotation.contents,
                   let data = contents.data(using: .utf8),
                   let payload = try? JSONDecoder().decode(Payload.self, from: data),
                   payload.syncseeker == "v1" {
                    page.removeAnnotation(annotation)
                    modified = true
                }
            }
        }

        if modified {
            try savePDF(doc, to: pdfURL)
        }
    }

    // MARK: - Private

    private func loadDocument(at url: URL) throws -> PDFDocument {
        guard let doc = PDFDocument(url: url) else {
            throw PDFHighlightError.invalidPDF(url)
        }
        return doc
    }

    /// `doc.write(to:)` は失敗してもエラーを返さない場合があるため、
    /// `dataRepresentation()` + `Data.write` でアトミックに書き出す。
    private func savePDF(_ doc: PDFDocument, to url: URL) throws {
        guard let data = doc.dataRepresentation() else {
            throw PDFHighlightError.writeFailed(url)
        }
        try data.write(to: url)
    }

#if canImport(AppKit)
    private func platformColor(from cgColor: CGColor) -> NSColor {
        return NSColor(cgColor: cgColor) ?? .yellow
    }
#else
    private func platformColor(from cgColor: CGColor) -> UIColor {
        return UIColor(cgColor: cgColor)
    }
#endif
}
