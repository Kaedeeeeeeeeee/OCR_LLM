import SwiftUI
#if os(macOS)
import AppKit

@main
struct QuickOCRLLMApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.viewModel)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = AppViewModel()
    private var menuBarController: MenuBarController?
    private let hotkey = HotkeyManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon at runtime (best effort without LSUIElement)
        NSApp.setActivationPolicy(.accessory)

        // Prepare menu bar
        menuBarController = MenuBarController(viewModel: viewModel)

        // Register default hotkey: Shift+Cmd+E
        hotkey.registerDefault(shift: true, command: true, key: .e) { [weak self] in
            Task { @MainActor in self?.viewModel.startCaptureAndOCR() }
        }

        // Request notification permission in background
        Notifications.requestAuthorizationIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkey.unregisterAll()
    }
}

#else
@main
struct UnsupportedPlatformStub: AsyncParsableCommand {
    static func main() {
        print("QuickOCRLLM requires macOS (AppKit). Please build on macOS using Xcode.")
    }
}
#endif
