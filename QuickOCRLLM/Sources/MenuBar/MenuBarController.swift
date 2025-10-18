import SwiftUI
#if os(macOS)
import AppKit

@MainActor
final class MenuBarController {
    private var statusItem: NSStatusItem!
    private let viewModel: AppViewModel
    private var settingsWC: SettingsWindowController?
    private var historyWC: HistoryWindowController?

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = makeStatusIcon()
        statusItem.button?.imagePosition = .imageOnly
        // Rely on NSStatusItem's default click-to-open when a menu is set.
        statusItem.menu = buildMenu()
        settingsWC = SettingsWindowController(viewModel: viewModel)
        historyWC = HistoryWindowController(viewModel: viewModel)
    }

    private func makeStatusIcon() -> NSImage? {
        // 1) Prefer asset named "StatusIconTemplate" as template image
        if let tpl = NSImage(named: "StatusIconTemplate") {
            tpl.isTemplate = true
            return tpl
        }
        // 2) Fallback to app icon scaled down (non-template). This uses AppIcon asset.
        if let appIcon = NSApplication.shared.applicationIconImage {
            let target: CGFloat = 18
            let resized = appIcon.resized(to: NSSize(width: target, height: target))
            resized.isTemplate = false
            return resized
        }
        // 3) Final fallback: SF Symbol
        return NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: nil)
    }
    @objc private func toggleMenu(_ sender: Any?) { }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Capture and OCR", action: #selector(capture), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Copy Last Result", action: #selector(copyLast), keyEquivalent: "")
        menu.addItem(withTitle: "Show Last Result", action: #selector(showLast), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        return menu
    }

    @objc private func capture() { viewModel.startCaptureAndOCR() }
    @objc private func copyLast() { Clipboard.copy(viewModel.lastResult) }
    @objc private func showLast() { historyWC?.show() }
    @objc private func openSettings() { settingsWC?.show() }
    @objc private func quit() { NSApp.terminate(nil) }
}

#endif
