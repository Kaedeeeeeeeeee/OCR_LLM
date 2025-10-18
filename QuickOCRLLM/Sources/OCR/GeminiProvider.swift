import Foundation

final class GeminiProvider: OCRProvider {
    let name = "Gemini"
    var model: String
    var apiKeyProvider: () -> String?

    init(model: String = "gemini-2.0-flash", apiKeyProvider: @escaping () -> String?) {
        self.model = model
        self.apiKeyProvider = apiKeyProvider
    }

    struct RequestBody: Encodable {
        struct Content: Encodable {
            let role: String
            let parts: [Part]
        }
        struct Part: Encodable {
            struct InlineData: Encodable { let mime_type: String; let data: String }
            let text: String?
            let inline_data: InlineData?
            init(text: String) { self.text = text; self.inline_data = nil }
            init(inlineData: InlineData) { self.text = nil; self.inline_data = inlineData }
        }
        let contents: [Content]
        struct GenerationConfig: Encodable { let temperature: Double }
        let generationConfig: GenerationConfig
    }

    struct ResponseBody: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable { struct Part: Decodable { let text: String? }; let parts: [Part] }
            let content: Content
        }
        let candidates: [Candidate]?
    }

    func recognize(imageData: Data, mode: OCRMode, languageHint: String?, timeout: TimeInterval) async throws -> String {
        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else { throw OCRProviderError.apiKeyMissing }
        // v1beta endpoint with 2.0 models
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!

        let prompt = "Extract plain text from this image. Return only the text, no extra commentary."
        let body = RequestBody(
            contents: [
                .init(role: "user", parts: [
                    .init(text: prompt),
                    .init(inlineData: .init(mime_type: "image/png", data: imageData.base64EncodedString()))
                ])
            ],
            generationConfig: .init(temperature: 0)
        )

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = timeout
        req.httpBody = try JSONEncoder().encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw OCRProviderError.requestFailed("HTTP \((resp as? HTTPURLResponse)?.statusCode ?? -1): \(text)")
        }
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let t = decoded.candidates?.first?.content.parts.compactMap({ $0.text }).joined(), !t.isEmpty else {
            throw OCRProviderError.invalidResponse
        }
        return postProcess(t)
    }

    private func postProcess(_ text: String) -> String {
        var t = text.replacingOccurrences(of: "\r", with: "")
        t = t.replacingOccurrences(of: "```", with: "")
        while t.contains("\n\n\n") { t = t.replacingOccurrences(of: "\n\n\n", with: "\n\n") }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
