import Foundation
import SwiftUI
import Combine

struct AppConfig: Codable {
    var autoCopy: Bool = true
    var showNotification: Bool = true
    var maxHistory: Int = 20
}

enum ConfigStore {
    private static var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CheeseOCR", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }

    static func load() -> AppConfig {
        guard let data = try? Data(contentsOf: url) else { return AppConfig() }
        return (try? JSONDecoder().decode(AppConfig.self, from: data)) ?? AppConfig()
    }

    static func save(_ cfg: AppConfig) { try? JSONEncoder().encode(cfg).write(to: url) }
}

// MARK: - Localization (Merged from Localization.swift)

enum Language: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case chinese = "zh-Hans"
    case japanese = "ja"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "System Default"
        case .english: return "English"
        case .chinese: return "简体中文"
        case .japanese: return "日本語"
        }
    }
}

final class LocalizationService: ObservableObject {
    static let shared = LocalizationService()
    
    @Published var currentLanguage: Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
            print("Changing language to: \(currentLanguage.rawValue)")
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
        }
    }
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: "app_language") ?? "system"
        self.currentLanguage = Language(rawValue: saved) ?? .system
    }
    
    var activeLocale: Locale {
        if currentLanguage == .system {
            return Locale.current
        }
        return Locale(identifier: currentLanguage.rawValue)
    }
    
    private var translations: [String: [String: String]] = [
        // Menu
        "Capture and OCR": [
            "zh-Hans": "截图并识别",
            "ja": "キャプチャしてOCR",
            "en": "Capture and OCR"
        ],
        "Copy Last Result": [
            "zh-Hans": "复制上次结果",
            "ja": "前回の結果をコピー",
            "en": "Copy Last Result"
        ],
        "Show More Result": [
            "zh-Hans": "显示更多结果",
            "ja": "その他の結果を表示",
            "en": "Show More Result"
        ],
        "Settings": [
            "zh-Hans": "设置…",
            "ja": "設定…",
            "en": "Settings…"
        ],
        "Quit": [
            "zh-Hans": "退出",
            "ja": "終了",
            "en": "Quit"
        ],
        
        // Settings - General
        "General": ["zh-Hans": "通用", "ja": "一般", "en": "General"],
        "Behavior": ["zh-Hans": "行为", "ja": "動作", "en": "Behavior"],
        "Launch at Login": ["zh-Hans": "开机自动启动", "ja": "ログイン時に起動", "en": "Launch at Login"],
        "Auto Copy to Clipboard": ["zh-Hans": "自动复制到剪贴板", "ja": "自動的にクリップボードにコピー", "en": "Auto Copy to Clipboard"],
        "Show Notification": ["zh-Hans": "显示识别结果弹窗", "ja": "認識結果ポップアップを表示", "en": "Show Result Popup"],
        "Data": ["zh-Hans": "数据", "ja": "データ", "en": "Data"],
        "Clear History & Cache": ["zh-Hans": "清除历史记录与缓存", "ja": "履歴とキャッシュを消去", "en": "Clear History & Cache"],
        
        // Settings - Advanced
        "History": ["zh-Hans": "历史记录", "ja": "履歴", "en": "History"],
        "History Limit": ["zh-Hans": "历史记录上限", "ja": "履歴件数上限", "en": "History Limit"],
        "Language": ["zh-Hans": "语言 / Language", "ja": "言語 / Language", "en": "Language"],
        
        // App Logic
        "OCR failed": ["zh-Hans": "识别失败", "ja": "OCR 失敗", "en": "OCR failed"],
        "Please enable 'Screen Recording' permission in System Settings and restart the app.": [
            "zh-Hans": "请在系统设置中为本应用开启‘屏幕录制’权限，然后重启应用。",
            "ja": "システム設定で「画面収録」の権限を有効にしてから、アプリを再起動してください。",
            "en": "Please enable 'Screen Recording' permission in System Settings and restart the app."
        ]
    ]
    
    func localize(_ key: String) -> String {
        let langCode = effectiveLanguageCode()
        
        // Try exact match
        if let dict = translations[key], let val = dict[langCode] {
            return val
        }
        
        // Fallback to English
        if let dict = translations[key], let val = dict["en"] {
            return val
        }
        
        // Fallback to key itself
        return key
    }
    
    private func effectiveLanguageCode() -> String {
        if currentLanguage == .system {
            let sysLang = (Locale.current.language.languageCode?.identifier ?? "en")
            if sysLang.contains("zh") { return "zh-Hans" }
            if sysLang.contains("ja") { return "ja" }
            return "en"
        }
        return currentLanguage.rawValue
    }
}

extension String {
    var localized: String {
        return LocalizationService.shared.localize(self)
    }
}

extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}
