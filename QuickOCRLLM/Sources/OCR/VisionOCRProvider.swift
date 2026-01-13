import Foundation
import Vision
import AppKit

/// Local OCR using Apple Vision Framework (Fast mode)
/// No network required, no API key needed
final class VisionOCRProvider: OCRProvider {
    let name = "Vision (Local)"
    
    func recognize(imageData: Data, mode: OCRMode, languageHint: String?, timeout: TimeInterval) async throws -> String {
        guard let image = NSImage(data: imageData),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRProviderError.invalidResponse
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRProviderError.requestFailed(error.localizedDescription))
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRProviderError.invalidResponse)
                    return
                }
                
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                
                continuation.resume(returning: text)
            }
            
            // Use accurate mode for better CJK language support
            request.recognitionLevel = .accurate
            
            // Support multiple languages - automatic detection
            request.recognitionLanguages = self.recognitionLanguages(hint: languageHint)
            request.automaticallyDetectsLanguage = true
            
            // Enable automatic language correction
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRProviderError.requestFailed(error.localizedDescription))
            }
        }
    }
    
    private func recognitionLanguages(hint: String?) -> [String] {
        // Default language priority: Japanese, Chinese, English, Korean
        var languages = ["ja-JP", "zh-Hans", "zh-Hant", "en-US", "ko-KR"]
        
        // If hint provided, prioritize that language
        if let hint = hint?.lowercased() {
            if hint.contains("ja") || hint.contains("japan") {
                languages.insert("ja-JP", at: 0)
            } else if hint.contains("zh") || hint.contains("chinese") {
                languages.insert("zh-Hans", at: 0)
            } else if hint.contains("ko") || hint.contains("korean") {
                languages.insert("ko-KR", at: 0)
            } else if hint.contains("en") || hint.contains("english") {
                languages.insert("en-US", at: 0)
            }
        }
        
        return languages
    }
}
