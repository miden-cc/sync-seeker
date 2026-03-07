import SwiftUI

public struct FileListView: View {
    public let documents: [Document]
    @Binding public var selection: Document?
    public var onTrash: ((Document) -> Void)?
    public var onRename: ((Document, String) -> Void)?
    public var folders: [Folder]
    public var onDuplicate: ((Document) -> Void)?
    public var onMove: ((Document, URL) -> Void)?

    @State private var documentToTrash: Document?
    @State private var showTrashAlert = false

    public init(
        documents: [Document],
        selection: Binding<Document?>,
        onTrash: ((Document) -> Void)? = nil,
        onRename: ((Document, String) -> Void)? = nil,
        folders: [Folder] = [],
        onDuplicate: ((Document) -> Void)? = nil,
        onMove: ((Document, URL) -> Void)? = nil
    ) {
        self.documents = documents
        self._selection = selection
        self.onTrash = onTrash
        self.onRename = onRename
        self.folders = folders
        self.onDuplicate = onDuplicate
        self.onMove = onMove
    }

    public var body: some View {
        List(documents, selection: $selection) { doc in
            FileRow(document: doc, onRename: onRename)
                .tag(doc)
                .contextMenu {
                    if onTrash != nil {
                        Button(role: .destructive) {
                            documentToTrash = doc
                            showTrashAlert = true
                        } label: {
                            Label("ゴミ箱に入れる", systemImage: "trash")
                        }
                        .keyboardShortcut(.delete, modifiers: .command)
                    }
                    if onDuplicate != nil {
                        Button {
                            onDuplicate?(doc)
                        } label: {
                            Label("複製", systemImage: "doc.on.doc")
                        }
                        .keyboardShortcut("d", modifiers: .command)
                    }
                    if onMove != nil && !folders.isEmpty {
                        Menu("移動先…") {
                            ForEach(folders) { folder in
                                Button {
                                    onMove?(doc, folder.path)
                                } label: {
                                    Label(folder.name, systemImage: "folder")
                                }
                            }
                        }
                    }
                }
        }
        .alert("ゴミ箱に入れますか？", isPresented: $showTrashAlert, presenting: documentToTrash) { doc in
            Button("キャンセル", role: .cancel) {}
            Button("ゴミ箱に入れる", role: .destructive) {
                onTrash?(doc)
            }
        } message: { doc in
            Text("「\(doc.name)」をゴミ箱に移動します。")
        }
        .overlay {
            if documents.isEmpty {
                ContentUnavailableView(
                    "ドキュメントなし",
                    systemImage: "tray",
                    description: Text("同期フォルダにファイルを追加してください")
                )
            }
        }
    }
}

public struct FileRow: View {
    public let document: Document
    public var onRename: ((Document, String) -> Void)?

    @State private var isEditing = false
    @State private var editName = ""
    @FocusState private var isFocused: Bool

    public init(document: Document, onRename: ((Document, String) -> Void)? = nil) {
        self.document = document
        self.onRename = onRename
    }

    public var body: some View {
        HStack {
            Image(systemName: iconFor(document.fileType))
                .foregroundStyle(colorFor(document.fileType))
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                if isEditing {
                    TextField("ファイル名", text: $editName)
                        .focused($isFocused)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            commitRename()
                        }
                        .onChange(of: isFocused) { focused in
                            if !focused {
                                commitRename()
                            }
                        }
                        .onExitCommand {
                            cancelRename()
                        }
                        .onAppear {
                            isFocused = true
                        }
                } else {
                    Text(document.name)
                        .lineLimit(1)
                        .onTapGesture(count: 2) {
                            startEditing()
                        }
                }

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

    private func startEditing() {
        if onRename == nil { return }
        let nameWithoutExt = (document.name as NSString).deletingPathExtension
        editName = nameWithoutExt
        isEditing = true
    }

    private func commitRename() {
        guard isEditing else { return }
        isEditing = false
        if !editName.isEmpty && editName != (document.name as NSString).deletingPathExtension {
            onRename?(document, editName)
        }
    }

    private func cancelRename() {
        isEditing = false
    }

    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: document.size, countStyle: .file)
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: document.modifiedDate)
    }

    private func iconFor(_ type: FileType) -> String {
        switch type {
        case .pdf:      return "doc.richtext"
        case .markdown: return "doc.text"
        case .plainText:return "doc.plaintext"
        case .richText: return "doc.richtext.fill"
        case .unknown:  return "doc.questionmark"
        }
    }

    private func colorFor(_ type: FileType) -> Color {
        switch type {
        case .pdf:      return .red
        case .markdown: return .blue
        case .plainText:return .secondary
        case .richText: return .orange
        case .unknown:  return .gray
        }
    }
}
