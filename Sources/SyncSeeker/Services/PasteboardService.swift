import Foundation

#if os(macOS)
import AppKit

public protocol PasteboardType {
    func clearContents() -> Int
    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool
}

extension NSPasteboard: PasteboardType {}

public struct PasteboardEnvironmentKey: EnvironmentKey {
    public static let defaultValue: PasteboardType = NSPasteboard.general
}

public extension EnvironmentValues {
    var pasteboard: PasteboardType {
        get { self[PasteboardEnvironmentKey.self] }
        set { self[PasteboardEnvironmentKey.self] = newValue }
    }
}
#endif
