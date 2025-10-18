import Foundation

enum OCRMode { case plainText }

protocol OCRProvider {
    var name: String { get }
    func recognize(imageData: Data, mode: OCRMode, languageHint: String?, timeout: TimeInterval) async throws -> String
}

enum OCRProviderError: Error, LocalizedError {
    case apiKeyMissing
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing: return "API Key missing"
        case .invalidResponse: return "Invalid response"
        case .requestFailed(let s): return s
        }
    }
}

