import SwiftUI
#if os(macOS)
import AppKit

@main
struct CheeseOCRApp: App {
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
        // Unit tests drive the OCR helper directly; don't register another global
        // shortcut or start a competing model warm-up in the test host.
        if NSClassFromString("XCTestCase") != nil { return }
        // Hide dock icon at runtime (best effort without LSUIElement)
        NSApp.setActivationPolicy(.accessory)

        // Prepare menu bar
        menuBarController = MenuBarController(viewModel: viewModel)

        // Warm the on-disk Vision models in a bounded helper process.
        VisionOCRProvider.prewarmInBackground()

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
        print("CheeseOCR requires macOS (AppKit). Please build on macOS using Xcode.")
    }
}
#endif
