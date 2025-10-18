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

    // Keychain masked getters
    var openAIKeyMasked: String { KeychainService.get(key: "openai_api_key")?.mask() ?? "" }
    var geminiKeyMasked: String { KeychainService.get(key: "gemini_api_key")?.mask() ?? "" }

    func setOpenAIKey(_ newValue: String) {
        // Store only if looks like a fresh key (starts with sk- or not masked)
        if !newValue.contains("•") && !newValue.trimmingCharacters(in: .whitespaces).isEmpty {
            _ = KeychainService.set(key: "openai_api_key", value: newValue.trimmingCharacters(in: .whitespaces))
        }
    }

    func setGeminiKey(_ newValue: String) {
        if !newValue.contains("•") && !newValue.trimmingCharacters(in: .whitespaces).isEmpty {
            _ = KeychainService.set(key: "gemini_api_key", value: newValue.trimmingCharacters(in: .whitespaces))
        }
    }

    func saveConfig() { ConfigStore.save(config) }

    func startCaptureAndOCR() {
        guard !isCapturing else { return }
        #if os(macOS)
        // Check screen recording permission first
        if !Permissions.hasScreenRecordingPermission() {
            Permissions.requestScreenRecordingPermissionAndOpenSettings()
            // Inform user to enable and relaunch
            Notifications.show(text: "请在系统设置中为本应用开启‘屏幕录制’权限，然后重启应用。")
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

            // Debug saving removed for clean build

            let provider = buildProvider()
            let text = try await provider.recognize(imageData: data, mode: .plainText, languageHint: nil, timeout: 20)

            lastResult = text
            history.add(text, limit: config.maxHistory)
            if config.autoCopy { Clipboard.copy(text) }
            if config.showNotification { Notifications.show(text: text) }
        } catch {
            lastResult = ""
            Notifications.show(text: "OCR failed: \(error.localizedDescription)")
        }
    }

    private func buildProvider() -> OCRProvider {
        switch config.provider {
        case .openAI:
            return OpenAIProvider(model: config.openAIModel) { KeychainService.get(key: "openai_api_key") }
        case .gemini:
            return GeminiProvider(model: config.geminiModel) { KeychainService.get(key: "gemini_api_key") }
        }
    }

    // 已移除自动切换 Provider 的兜底逻辑
}

private extension String {
    func mask() -> String {
        let trimmed = trimmingCharacters(in: .whitespaces)
        guard trimmed.count > 8 else { return String(repeating: "•", count: trimmed.count) }
        let prefix = trimmed.prefix(4)
        let suffix = trimmed.suffix(4)
        return "\(prefix)\(String(repeating: "•", count: max(0, trimmed.count - 8)))\(suffix)"
    }
}
