import Foundation
import SwiftUI
import SyncSeeker

struct FileListView: View {
    let documents: [SyncSeeker.Document]
    @Binding var selection: SyncSeeker.Document?

    var body: some View {
        List(documents, selection: $selection) { doc in
            FileRow(document: doc)
                .tag(doc)
        }
        .overlay {
            if documents.isEmpty {
                ContentUnavailableView(
                    "ドキュメントなし",
                    systemImage: "tray",
                    description: Text("~/SyncSeeker/ にファイルを追加してください")
                )
            }
        }
    }
}

struct FileRow: View {
    let document: SyncSeeker.Document

    var body: some View {
        HStack {
            Image(systemName: iconFor(document.fileType))
                .foregroundStyle(colorFor(document.fileType))
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(document.name)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(formattedSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !document.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(document.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: document.size, countStyle: .file)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: document.modifiedDate)
    }

    private func iconFor(_ type: SyncSeeker.FileType) -> String {
        switch type {
        case .pdf: return "doc.richtext"
        case .markdown: return "doc.text"
        case .plainText: return "doc.plaintext"
        case .richText: return "doc.richtext.fill"
        case .unknown: return "doc.questionmark"
        }
    }

    private func colorFor(_ type: SyncSeeker.FileType) -> Color {
        switch type {
        case .pdf: return .red
        case .markdown: return .blue
        case .plainText: return .secondary
        case .richText: return .orange
        case .unknown: return .gray
        }
    }
}
