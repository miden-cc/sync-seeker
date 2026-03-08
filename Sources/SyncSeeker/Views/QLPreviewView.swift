import SwiftUI
import QuickLook

#if os(iOS)
public struct QLPreviewView: UIViewControllerRepresentable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func makeUIViewController(context: Context) -> UINavigationController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        let navigationController = UINavigationController(rootViewController: controller)
        return navigationController
    }

    public func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        if let controller = uiViewController.viewControllers.first as? QLPreviewController {
            controller.reloadData()
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: QLPreviewView

        init(_ parent: QLPreviewView) {
            self.parent = parent
        }

        public func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        public func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.url as QLPreviewItem
        }
    }
}
#endif
