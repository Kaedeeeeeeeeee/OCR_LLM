import SwiftUI
#if os(macOS)
import AppKit

@MainActor
final class HistoryWindowController {
    private var window: NSWindow?
    private weak var viewModel: AppViewModel?

    init(viewModel: AppViewModel) { self.viewModel = viewModel }

    func show() {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        guard let vm = viewModel else { return }
        let view = HistoryView().environmentObject(vm)
        let hosting = NSHostingView(rootView: view)
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 500),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        w.center()
        w.title = "OCR History"
        w.isReleasedWhenClosed = false
        w.contentView = hosting
        self.window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

#endif

