import Foundation

public enum LocalFileServiceError: Error {
    case unsupportedFileType(FileType)
    case encodingError(URL)
}

public struct LocalFileService: FileServiceProtocol {

    public init() {}

    public func listFolders(at path: URL) throws -> [Folder] {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: path, includingPropertiesForKeys: [.isDirectoryKey])

        return try contents.compactMap { url in
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else { return nil }
            return Folder(
                id: UUID(),
                name: url.lastPathComponent,
                path: url,
                children: [],
                documents: []
            )
        }
    }

    public func listDocuments(in folder: Folder) throws -> [Document] {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(
            at: folder.path,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        )

        return try contents.compactMap { url in
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
            guard values.isDirectory != true else { return nil }
            return Document(
                id: UUID(),
                name: url.lastPathComponent,
                path: url,
                size: Int64(values.fileSize ?? 0),
                modifiedDate: values.contentModificationDate ?? Date(),
                fileType: detectFileType(at: url),
                tags: []
            )
        }
    }

    public func readContent(of document: Document) throws -> String {
        switch document.fileType {
        case .pdf, .richText:
            throw LocalFileServiceError.unsupportedFileType(document.fileType)
        case .markdown, .plainText, .unknown:
            guard let content = try? String(contentsOf: document.path, encoding: .utf8) else {
                throw LocalFileServiceError.encodingError(document.path)
            }
            return content
        }
    }

    public func detectFileType(at path: URL) -> FileType {
        let ext = path.pathExtension.lowercased()
        switch ext {
        case "pdf": return .pdf
        case "md", "markdown": return .markdown
        case "txt", "text": return .plainText
        case "rtf", "rtfd": return .richText
        default: return .unknown
        }
    }
}
