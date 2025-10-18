import SwiftUI
#if os(macOS)
import AppKit

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private weak var viewModel: AppViewModel?

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    func show() {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let content = SettingsView().environmentObject(viewModel!)
        let hosting = NSHostingView(rootView: content)
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
                         styleMask: [.titled, .closable, .miniaturizable],
                         backing: .buffered, defer: false)
        w.center()
        w.title = "Settings"
        w.isReleasedWhenClosed = false
        w.contentView = hosting
        self.window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

#endif

