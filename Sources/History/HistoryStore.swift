import Foundation

struct OCRRecord: Codable, Identifiable { let id = UUID(); let text: String; let timestamp: Date }

final class HistoryStore: ObservableObject {
    @Published private(set) var items: [OCRRecord] = []

    private var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("QuickOCRLLM", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }

    func load() {
        if let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode([OCRRecord].self, from: data) {
            items = decoded
        }
    }

    func add(_ text: String, limit: Int) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        items.insert(.init(text: text, timestamp: Date()), at: 0)
        if items.count > limit { items = Array(items.prefix(limit)) }
        save()
    }

    private func save() { if let data = try? JSONEncoder().encode(items) { try? data.write(to: url) } }
}

