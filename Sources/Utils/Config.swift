import Foundation

struct AppConfig: Codable {
    var provider: Provider = .openAI
    var openAIModel: String = "gpt-4o-mini"
    var geminiModel: String = "gemini-2.0-flash"
    var autoCopy: Bool = true
    var showNotification: Bool = true
    var maxHistory: Int = 10
    var imageMaxDimension: CGFloat = 1440
    var jpegQuality: Double = 0.85
    var useNativeScreencapture: Bool = true

    enum Provider: String, Codable { case openAI, gemini }
}

enum ConfigStore {
    private static var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("QuickOCRLLM", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }

    static func load() -> AppConfig {
        guard let data = try? Data(contentsOf: url) else { return AppConfig() }
        return (try? JSONDecoder().decode(AppConfig.self, from: data)) ?? AppConfig()
    }

    static func save(_ cfg: AppConfig) { try? JSONEncoder().encode(cfg).write(to: url) }
}
