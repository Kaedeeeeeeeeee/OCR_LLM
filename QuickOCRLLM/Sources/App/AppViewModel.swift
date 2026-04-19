import SwiftUI
import Combine
import AppKit

@MainActor
final class AppViewModel: ObservableObject {
    @Published var config: AppConfig = ConfigStore.load()
    @Published var lastResult: String = ""
    @Published var isCapturing: Bool = false
    let history = HistoryStore()

    init() {
        history.load()
    }

    func saveConfig() { ConfigStore.save(config) }

    func startCaptureAndOCR() {
        guard !isCapturing else { return }
        #if os(macOS)
        // Check screen recording permission first
        if !Permissions.hasScreenRecordingPermission() {
            Permissions.requestScreenRecordingPermissionAndOpenSettings()
            // Inform user to enable and relaunch
            Notifications.show(text: "Please enable 'Screen Recording' permission in System Settings and restart the app.".localized)
            return
        }
        #endif

        isCapturing = true
        // 直接走原生选区截屏，不再显示自定义灰色遮罩
        Task { [weak self] in
            await self?.handleSelection(nil)
        }
    }

    private func handleSelection(_ rectOpt: CGRect?) async {
        defer { isCapturing = false }
        do {
            // Always use native interactive selection; returns PNG data or nil if canceled
            let data = try await NativeScreencapture.captureSelectionToPNG()
            guard let data else { return }

            let provider = VisionOCRProvider()
            let text = try await provider.recognize(imageData: data, mode: .plainText, languageHint: nil, timeout: 20)

            lastResult = text
            history.add(text, limit: config.maxHistory)
            if config.autoCopy { Clipboard.copy(text) }
            if config.showNotification {
                HUDManager.shared.show(text: text, mascotOverride: config.mascotStyle)
            }
        } catch {
            lastResult = ""
            HUDManager.shared.show(text: "\("OCR failed".localized): \(error.localizedDescription)", icon: "xmark.circle.fill", isError: true)
        }
    }
}
