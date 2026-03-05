import Foundation

protocol FileServiceProtocol {
    func listFolders(at path: URL) throws -> [Folder]
    func listDocuments(in folder: Folder) throws -> [Document]
    func readContent(of document: Document) throws -> String
    func detectFileType(at path: URL) -> FileType
}
