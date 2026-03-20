import SwiftUI
#if os(macOS)
import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let viewModel: AppViewModel
    private var settingsWC: SettingsWindowController?
    private var historyWC: HistoryWindowController?

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        super.init()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = makeStatusIcon()
        statusItem.button?.imagePosition = .imageOnly
        // Rely on NSStatusItem's default click-to-open when a menu is set.
        statusItem.menu = buildMenu()
        settingsWC = SettingsWindowController(viewModel: viewModel)
        historyWC = HistoryWindowController(viewModel: viewModel)
        
        // Listen for language changes to rebuild menu immediately (though menuNeedsUpdate handles dynamic opens)
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .languageDidChange, object: nil)
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
    
    @objc private func languageChanged() {
        // Technically menuNeedsUpdate is called when menu opens, so just clearing it might be enough or irrelevant.
        // But updating titles of existing windows if they were open would happen via SwiftUI state.
        // For menu, it's rebuilt on open. We can do nothing here, or force a rebuild if we weren't using lazy delegate.
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        return menu
    }

    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let target = self
        
        let captureItem = menu.addItem(withTitle: "Capture and OCR".localized, action: #selector(capture), keyEquivalent: "e")
        captureItem.keyEquivalentModifierMask = [.command, .shift]
        
        menu.addItem(NSMenuItem.separator())
        
        // Show recent 5 items
        let recentItems = viewModel.history.items.prefix(5)
        if !recentItems.isEmpty {
            for item in recentItems {
                var text = item.text.replacingOccurrences(of: "\n", with: " ")
                if text.count > 20 {
                    text = String(text.prefix(20)) + "..."
                }
                let menuItem = NSMenuItem(title: text, action: #selector(copyHistoryItem(_:)), keyEquivalent: "")
                menuItem.target = target
                menuItem.representedObject = item.text
                menu.addItem(menuItem)
            }
            menu.addItem(NSMenuItem.separator())
        }
        
        menu.addItem(withTitle: "Show More Result".localized, action: #selector(showLast), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Settings".localized, action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "Quit".localized, action: #selector(quit), keyEquivalent: "q")
        
        menu.items.forEach { 
            if $0.target == nil { $0.target = target }
        }
    }

    @objc private func capture() { viewModel.startCaptureAndOCR() }
    @objc private func copyHistoryItem(_ sender: NSMenuItem) {
        if let text = sender.representedObject as? String {
            Clipboard.copy(text)
            HUDManager.shared.show(text: text)
        }
    }
    @objc private func showLast() { historyWC?.show() }
    @objc private func openSettings() { settingsWC?.show() }
    @objc private func quit() { NSApp.terminate(nil) }
}

#endif
