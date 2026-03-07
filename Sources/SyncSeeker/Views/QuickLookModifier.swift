import SwiftUI

#if os(macOS)
import Quartz

struct QuickLookModifier: ViewModifier {
    let document: Document?
    @State private var quickLookDataSource = QuickLookDataSource()

    func body(content: Content) -> some View {
        content
            .background(QuickLookRepresentable(dataSource: quickLookDataSource))
            .onKeyPress(.space) {
                if let panel = QLPreviewPanel.shared() {
                    if panel.isVisible {
                        panel.orderOut(nil)
                    } else if document != nil {
                        quickLookDataSource.document = document
                        panel.makeKeyAndOrderFront(nil)
                        panel.reloadData()
                    }
                    return .handled
                }
                return .ignored
            }
            .onChange(of: document) { _, newDoc in
                quickLookDataSource.document = newDoc
            }
    }
}

class QuickLookDataSource: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    var document: Document? {
        didSet {
            if let panel = QLPreviewPanel.shared(), panel.isVisible {
                panel.reloadData()
            }
        }
    }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        return true
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = self
        panel.delegate = self
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        panel.delegate = nil
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return document != nil ? 1 : 0
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        return document?.path as QLPreviewItem?
    }
}

class QLPreviewPanelHandlerView: NSView {
    var dataSource: QuickLookDataSource?

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        return dataSource?.acceptsPreviewPanelControl(panel) ?? false
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        dataSource?.beginPreviewPanelControl(panel)
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        dataSource?.endPreviewPanelControl(panel)
    }
}

struct QuickLookRepresentable: NSViewRepresentable {
    var dataSource: QuickLookDataSource

    func makeNSView(context: Context) -> QLPreviewPanelHandlerView {
        let view = QLPreviewPanelHandlerView()
        view.dataSource = dataSource

        // We do NOT steal first responder.
        // Instead, we inject ourselves into the responder chain when the window is available
        DispatchQueue.main.async {
            if let window = view.window {
                // Find a suitable place in the responder chain
                // Let's insert it right after the window's first responder if possible,
                // or after the view itself
                let currentNext = view.nextResponder
                view.nextResponder = window.firstResponder?.nextResponder
                window.firstResponder?.nextResponder = view
            }
        }

        return view
    }

    func updateNSView(_ nsView: QLPreviewPanelHandlerView, context: Context) {
        nsView.dataSource = dataSource
    }
}

public extension View {
    func quickLookPreview(document: Document?) -> some View {
        modifier(QuickLookModifier(document: document))
    }
}
#else
public extension View {
    func quickLookPreview(document: Document?) -> some View {
        self
    }
}
#endif
