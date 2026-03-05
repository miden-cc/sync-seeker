import Foundation
import Testing
@testable import SyncSeeker

@Suite("Folder Model")
struct FolderTests {

    @Test("Folder creation with empty children")
    func creation() {
        let url = URL(fileURLWithPath: "/tmp/work")
        let folder = Folder(id: UUID(), name: "work", path: url, children: [], documents: [])

        #expect(folder.name == "work")
        #expect(folder.children.isEmpty)
        #expect(folder.documents.isEmpty)
    }

    @Test("Folder with nested children")
    func withChildren() {
        let parentURL = URL(fileURLWithPath: "/tmp/work")
        let childURL = URL(fileURLWithPath: "/tmp/work/contracts")

        let child = Folder(id: UUID(), name: "contracts", path: childURL, children: [], documents: [])
        let parent = Folder(id: UUID(), name: "work", path: parentURL, children: [child], documents: [])

        #expect(parent.children.count == 1)
        #expect(parent.children.first?.name == "contracts")
    }

    @Test("Folder with documents")
    func withDocuments() {
        let folderURL = URL(fileURLWithPath: "/tmp/work")
        let docURL = URL(fileURLWithPath: "/tmp/work/memo.md")

        let doc = Document(id: UUID(), name: "memo.md", path: docURL, size: 256, modifiedDate: Date(), fileType: .markdown, tags: [])
        let folder = Folder(id: UUID(), name: "work", path: folderURL, children: [], documents: [doc])

        #expect(folder.documents.count == 1)
        #expect(folder.documents.first?.name == "memo.md")
    }
}
