@_exported import Foundation
#if os(macOS)
import AppKit

enum Clipboard {
    static func copy(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}

#else
enum Clipboard { static func copy(_ text: String) { /* no-op on non-macOS */ } }
#endif
