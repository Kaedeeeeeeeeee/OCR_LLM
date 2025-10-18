import Foundation
#if os(macOS)
import AppKit
import CoreGraphics

enum Permissions {
    static func hasScreenRecordingPermission() -> Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightScreenCaptureAccess()
        } else {
            return true
        }
    }

    @discardableResult
    static func requestScreenRecordingPermissionAndOpenSettings() -> Bool {
        var granted = false
        if #available(macOS 10.15, *) {
            granted = CGRequestScreenCaptureAccess()
        }
        openScreenRecordingSettings()
        return granted
    }

    static func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
}

#endif

