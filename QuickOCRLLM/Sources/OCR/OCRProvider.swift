import Foundation

enum OCRMode { case plainText }

protocol OCRProvider {
    var name: String { get }
    func recognize(imageData: Data, mode: OCRMode, languageHint: String?, timeout: TimeInterval) async throws -> String
}

enum OCRProviderError: Error, LocalizedError {
    case invalidResponse
    case requestFailed(String)
    case timedOut

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response"
        case .requestFailed(let s): return s
        case .timedOut: return "OCR timed out"
        }
    }
}
