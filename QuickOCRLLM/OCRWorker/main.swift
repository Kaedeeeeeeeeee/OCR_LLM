import Foundation
import Vision
import CoreGraphics
import CoreText
import ImageIO

// On macOS 27, TextRecognition can retain missing ANE cache paths for the
// lifetime of a process. The parent restarts this helper to recover, and enforces
// deadlines externally because VNRequest.cancel() is cooperative.
func warmupImage() throws -> CGImage {
    guard let context = CGContext(data: nil, width: 640, height: 160,
                                  bitsPerComponent: 8, bytesPerRow: 640 * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        throw NSError(domain: "CheeseOCRWorker", code: 1)
    }
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 640, height: 160))
    context.textPosition = CGPoint(x: 24, y: 62)
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateUIFontForLanguage(.system, 30, nil) as Any,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1),
    ]
    CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(
        string: "Cheese OCR warm up · 中文 · 日本語 · 한국어", attributes: attributes)), context)
    guard let image = context.makeImage() else { throw NSError(domain: "CheeseOCRWorker", code: 1) }
    return image
}

func recognize(inputPath: String, languageHint: String) throws -> String {
    let image: CGImage
    if inputPath == "--warmup" {
        image = try warmupImage()
    } else {
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: inputPath) as CFURL, nil),
              let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw NSError(domain: "CheeseOCRWorker.InvalidImage", code: 1)
        }
        image = decoded
    }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    var languages = ["ja-JP", "zh-Hans", "zh-Hant", "en-US", "ko-KR"]
    let hint = languageHint.lowercased()
    let preferred: String?
    if hint.contains("ja") || hint.contains("japan") { preferred = "ja-JP" }
    else if hint.contains("zh") || hint.contains("chinese") { preferred = "zh-Hans" }
    else if hint.contains("ko") || hint.contains("korean") { preferred = "ko-KR" }
    else if hint.contains("en") || hint.contains("english") { preferred = "en-US" }
    else { preferred = nil }
    if let preferred {
        languages.removeAll { $0 == preferred }
        languages.insert(preferred, at: 0)
    }
    request.recognitionLanguages = languages
    request.automaticallyDetectsLanguage = true
    request.usesLanguageCorrection = true
    try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    guard let results = request.results else { throw NSError(domain: "CheeseOCRWorker.InvalidResponse", code: 1) }
    return results.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
}

func handle(_ arguments: [String]) throws {
    guard arguments.count == 3 else { throw NSError(domain: "CheeseOCRWorker.Protocol", code: 1) }
    let inputPath = arguments[0]
    let outputURL = URL(fileURLWithPath: arguments[1])
    let languageHint = arguments[2]
    #if DEBUG
    // Fault injection lives only in the Debug helper. Tests exercise the real signed
    // subprocess and sandbox instead of attempting to execute scripts from app data.
    if let scenario = ProcessInfo.processInfo.environment["CHEESE_OCR_TEST_SCENARIO"] {
        let directory = outputURL.deletingLastPathComponent()
        let marker = directory.appendingPathComponent("first-pid")
        let firstPID = try? String(contentsOf: marker, encoding: .utf8)
        let pid = String(ProcessInfo.processInfo.processIdentifier)
        if firstPID == nil { try pid.write(to: marker, atomically: true, encoding: .utf8) }
        if let evidencePath = ProcessInfo.processInfo.environment["CHEESE_OCR_TEST_EVIDENCE"] {
            try "\(pid)|\(directory.path)".write(toFile: evidencePath, atomically: true, encoding: .utf8)
        }
        var response: [String: Any]
        switch scenario {
        case "hang":
            signal(SIGTERM, SIG_IGN)
            while true { pause() }
        case "crash" where firstPID == nil:
            kill(getpid(), SIGKILL)
            exit(70)
        case "crash": response = ["text": "recovered"]
        case "model" where firstPID != nil:
            response = ["text": "\(firstPID!)|\(pid)|\(inputPath)"]
        case "model", "persistent":
            response = ["errors": [["domain": "TextRecognition.CRImageReaderError", "code": 1]],
                        "message": "attempt \(firstPID == nil ? 1 : 2)"]
        default: response = ["errors": [["domain": "ImageIO", "code": 1]], "message": "bad input"]
        }
        try JSONSerialization.data(withJSONObject: response).write(to: outputURL, options: .atomic)
        return
    }
    #endif


    let response: [String: Any] = autoreleasepool {
        do { return ["text": try recognize(inputPath: inputPath, languageHint: languageHint)] }
        catch {
            let error = error as NSError
            // Preserve the actual domains/codes for recovery; never log image/text contents.
            var errors: [[String: Any]] = []
            var current: NSError? = error
            for _ in 0..<8 {
                guard let entry = current else { break }
                errors.append(["domain": entry.domain, "code": entry.code])
                current = entry.userInfo[NSUnderlyingErrorKey] as? NSError
            }
            return ["errors": errors, "message": error.localizedDescription]
        }
    }
    try JSONSerialization.data(withJSONObject: response).write(to: outputURL, options: .atomic)
}

// Reading commands until EOF keeps warmed models alive; the parent restarts this
// process after a model failure, deadline, or cancellation.
let parentPID = getppid()
let watchdog = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
watchdog.schedule(deadline: .now() + 5, repeating: 5)
watchdog.setEventHandler { if getppid() != parentPID { exit(0) } }
watchdog.resume()
while let line = readLine() {
    do {
        let arguments = try JSONDecoder().decode([String].self, from: Data(line.utf8))
        try autoreleasepool { try handle(arguments) }
        try FileHandle.standardOutput.write(contentsOf: Data([0x0a]))
    } catch { exit(74) }
}
