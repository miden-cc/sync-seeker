import Foundation

/// QuickLook プレビュー用 HTML を生成するサービス。
/// Finder 上でドキュメントを選択した際に AI 要約・タグ・ハイライト・OCR を表示する。
///
/// 実際の QuickLook プラグイン（QLPreviewingController）は Xcode ターゲットで作成し、
/// このジェネレーターを呼び出して HTML を返す構成とする。
struct QuickLookPreviewGenerator {

    // MARK: - Public API

    /// 各メタデータから HTML プレビューを生成する。
    func generatePreview(
        fileName: String,
        summary: String?,
        tags: [String],
        highlights: [String],
        ocrExcerpt: String?
    ) -> String {
        var sections: [String] = []

        // Summary
        if let summary, !summary.isEmpty {
            sections.append(section(title: "AI Summary", body: "<p>\(esc(summary))</p>"))
        }

        // Tags
        if !tags.isEmpty {
            let pills = tags.map { "<span class=\"tag\">\(esc($0))</span>" }.joined(separator: " ")
            sections.append(section(title: "Tags", body: pills))
        }

        // Highlights
        if !highlights.isEmpty {
            let items = highlights.map { "<li>\(esc($0))</li>" }.joined(separator: "\n")
            sections.append(section(title: "Highlights", body: "<ul>\(items)</ul>"))
        }

        // OCR excerpt
        if let ocrExcerpt, !ocrExcerpt.isEmpty {
            sections.append(section(title: "OCR Text", body: "<pre>\(esc(ocrExcerpt))</pre>"))
        }

        if sections.isEmpty {
            sections.append("<p class=\"empty\">No AI metadata available.</p>")
        }

        return html(title: fileName, body: sections.joined(separator: "\n"))
    }

    /// Document モデルから直接プレビューを生成するコンビニエンスメソッド。
    func generatePreview(from document: Document, highlights: [String], ocrExcerpt: String?) -> String {
        generatePreview(
            fileName: document.name,
            summary: document.summary,
            tags: document.tags,
            highlights: highlights,
            ocrExcerpt: ocrExcerpt
        )
    }

    // MARK: - Private HTML helpers

    private func html(title: String, body: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <title>\(esc(title)) — SyncSeeker</title>
        <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 20px; color: #1d1d1f; background: #fafafa; }
        h1 { font-size: 18px; margin-bottom: 4px; }
        h2 { font-size: 14px; color: #636366; margin-top: 16px; margin-bottom: 6px; text-transform: uppercase; letter-spacing: 0.5px; }
        p { font-size: 14px; line-height: 1.5; }
        .tag { display: inline-block; background: #e8e8ed; border-radius: 10px; padding: 2px 10px; margin: 2px; font-size: 12px; color: #3a3a3c; }
        ul { padding-left: 20px; font-size: 14px; line-height: 1.6; }
        pre { background: #f5f5f7; padding: 12px; border-radius: 8px; font-size: 12px; white-space: pre-wrap; overflow-x: auto; }
        .empty { color: #8e8e93; font-style: italic; }
        @media (prefers-color-scheme: dark) {
          body { background: #1c1c1e; color: #f5f5f7; }
          .tag { background: #3a3a3c; color: #e5e5ea; }
          pre { background: #2c2c2e; }
          h2 { color: #98989d; }
          .empty { color: #636366; }
        }
        </style>
        </head>
        <body>
        <h1>\(esc(title))</h1>
        \(body)
        </body>
        </html>
        """
    }

    private func section(title: String, body: String) -> String {
        "<h2>\(esc(title))</h2>\n\(body)"
    }

    /// HTML エスケープ。
    private func esc(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
