import SwiftUI

public struct DocumentPreviewView: View {
    public let document: Document
    @State private var textContent: String?
    @State private var summary: String?

    public init(document: Document) {
        self.document = document
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(document.name)
                            .font(.title2)
                        Text(formattedSize + " / " + formattedDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
#if os(macOS)
                    Button("Finder で開く") {
                        NSWorkspace.shared.activateFileViewerSelecting([document.path])
                    }
#else
                    ShareLink(item: document.path) {
                        Label("共有", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
#endif
                }

                Divider()

                if !document.tags.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(document.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.blue.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }

                if let summary {
                    GroupBox("AI 要約") {
                        Text(summary).font(.body)
                    }
                }

                if let text = textContent {
                    GroupBox("内容プレビュー") {
                        Text(text.prefix(2000))
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                } else if document.fileType == .pdf {
                    GroupBox("プレビュー") {
                        Text("PDF プレビューは今後実装予定")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .task(id: document.id) { loadContent() }
    }

    private func loadContent() {
        let service = LocalFileService()
        textContent = try? service.readContent(of: document)
        let annotation = XattrAnnotationService()
        summary = try? annotation.readFinderComment(at: document.path)
    }

    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: document.size, countStyle: .file)
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: document.modifiedDate)
    }
}

public struct FlowLayout: Layout {
    public var spacing: CGFloat

    public init(spacing: CGFloat = 4) {
        self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
