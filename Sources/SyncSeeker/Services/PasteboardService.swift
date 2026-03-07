import Foundation

#if os(macOS)
import AppKit

public enum PasteboardService {
    public static func copyPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }
}
#endif
