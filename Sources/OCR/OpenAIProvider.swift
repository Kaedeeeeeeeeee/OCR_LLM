import Foundation

final class OpenAIProvider: OCRProvider {
    let name = "OpenAI"
    var model: String
    var apiKeyProvider: () -> String?

    init(model: String = "gpt-4o-mini", apiKeyProvider: @escaping () -> String?) {
        self.model = model
        self.apiKeyProvider = apiKeyProvider
    }

    struct ChatRequest: Encodable {
        struct Message: Encodable {
            struct ContentPartText: Encodable { let type = "text"; let text: String }
            struct ContentPartImageURL: Encodable {
                struct ImageURL: Encodable { let url: String }
                let type = "image_url"
                let image_url: ImageURL
            }
            let role: String
            let content: [EncodableWrapper]
        }
        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int
    }

    struct EncodableWrapper: Encodable {
        private let _encode: (Encoder) throws -> Void
        init<E: Encodable>(_ wrapped: E) { _encode = wrapped.encode }
        func encode(to encoder: Encoder) throws { try _encode(encoder) }
    }

    struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message
        }
        let choices: [Choice]
    }

    func recognize(imageData: Data, mode: OCRMode, languageHint: String?, timeout: TimeInterval) async throws -> String {
        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else { throw OCRProviderError.apiKeyMissing }
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        let prompt = "Extract plain text from this image. The text may include Chinese/Japanese/Korean/English. Preserve natural line breaks. Return only the text. No translation, no commentary."
        let dataURI = "data:image/png;base64,\(imageData.base64EncodedString())"

        let message = ChatRequest.Message(
            role: "user",
            content: [
                .init(ChatRequest.Message.ContentPartText(text: prompt)),
                .init(ChatRequest.Message.ContentPartImageURL(image_url: .init(url: dataURI)))
            ]
        )

        let body = ChatRequest(model: model, messages: [message], temperature: 0, max_tokens: 4096)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = timeout
        req.httpBody = try JSONEncoder().encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw OCRProviderError.requestFailed("HTTP \((resp as? HTTPURLResponse)?.statusCode ?? -1): \(text)")
        }
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content, !text.isEmpty else {
            throw OCRProviderError.invalidResponse
        }
        return postProcess(text)
    }

    private func postProcess(_ text: String) -> String {
        // Normalize whitespace and strip code fences if any slip through
        var t = text.replacingOccurrences(of: "\r", with: "")
        // remove common markdown fences
        t = t.replacingOccurrences(of: "```", with: "")
        // collapse 3+ newlines into 2
        while t.contains("\n\n\n") { t = t.replacingOccurrences(of: "\n\n\n", with: "\n\n") }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
