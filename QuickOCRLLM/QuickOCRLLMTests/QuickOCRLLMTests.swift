import Testing
import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
import Darwin
@testable import Cheese__OCR

@Suite(.serialized)
struct OCRRecoveryTests {
    private func fixture(_ text: String = "Cheese OCR 123", font: String = "Helvetica", width: Int = 900, height: Int = 140) throws -> Data {
        let context = try #require(CGContext(data: nil, width: width, height: height,
                                           bitsPerComponent: 8, bytesPerRow: width * 4,
                                           space: CGColorSpaceCreateDeviceRGB(),
                                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.textPosition = CGPoint(x: 12, y: height / 2)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName(font as CFString, 28, nil),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1),
        ]
        CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes)), context)
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func runner(_ scenario: String, evidence: URL? = nil) -> OCRWorkerRunner {
        var environment = ["CHEESE_OCR_TEST_SCENARIO": scenario]
        if let evidence { environment["CHEESE_OCR_TEST_EVIDENCE"] = evidence.path }
        return OCRWorkerRunner(workerEnvironment: environment)
    }

    @Test func modelFailureRetriesInFreshProcessAndCleansImages() async throws {
        let result = try await runner("model").run(imageData: fixture(), languageHint: nil, timeout: 5)
        let parts = result.components(separatedBy: "|")
        #expect(parts.count == 3)
        #expect(parts[0] != parts[1])
        #expect(!FileManager.default.fileExists(atPath: parts[2]))
        #expect(!FileManager.default.fileExists(atPath: URL(fileURLWithPath: parts[2]).deletingLastPathComponent().path))
    }

    @Test func persistentModelFailureStopsAfterTwoAttempts() async throws {
        do {
            _ = try await runner("persistent").run(imageData: fixture(), languageHint: nil, timeout: 5)
            Issue.record("Persistent model failure should be reported")
        } catch { #expect(error.localizedDescription == "attempt 2") }
    }

    @Test func invalidImageIsNotRetried() async throws {
        do {
            _ = try await OCRWorkerRunner().run(imageData: Data("not an image".utf8), languageHint: nil, timeout: 5)
            Issue.record("Invalid image should be rejected")
        } catch { #expect(error.localizedDescription == "Invalid response") }
    }

    @Test func unrelatedFailureIsNotRetried() async throws {
        do {
            _ = try await runner("unrelated").run(imageData: fixture(), languageHint: nil, timeout: 5)
            Issue.record("Unrelated failures must not be hidden by retry")
        } catch { #expect(error.localizedDescription == "bad input") }
    }

    @Test func terminatedWorkerRetriesOnce() async throws {
        #expect(try await runner("crash").run(imageData: fixture(), languageHint: nil, timeout: 5) == "recovered")
    }

    @Test func repeatedRecoveryDoesNotBlockCleanup() async throws {
        let data = try fixture()
        for _ in 0..<20 {
            #expect(try await runner("crash").run(imageData: data, languageHint: nil, timeout: 5) == "recovered")
        }
    }

    @Test func hungWorkerIsKilledAndNextRequestWorks() async throws {
        let evidence = FileManager.default.temporaryDirectory.appendingPathComponent("OCR-Test-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: evidence) }
        let started = ProcessInfo.processInfo.systemUptime
        do {
            _ = try await runner("hang", evidence: evidence).run(imageData: fixture(), languageHint: nil, timeout: 0.5)
            Issue.record("Hung worker should time out")
        } catch { #expect(error.localizedDescription == "OCR timed out") }
        #expect(ProcessInfo.processInfo.systemUptime - started < 3)
        let parts = try String(contentsOf: evidence, encoding: .utf8).components(separatedBy: "|")
        let pid = try #require(Int32(parts[0]))
        #expect(kill(pid, 0) == -1)
        #expect(errno == ESRCH)
        #expect(!FileManager.default.fileExists(atPath: parts[1]))
        #expect(try await OCRWorkerRunner().run(imageData: fixture(), languageHint: nil, timeout: 60) == "Cheese OCR 123")
    }

    @Test func cancellationReapsWorker() async throws {
        let evidence = FileManager.default.temporaryDirectory.appendingPathComponent("OCR-Test-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: evidence) }
        let data = try fixture()
        let task = Task { try await runner("hang", evidence: evidence).run(imageData: data, languageHint: nil, timeout: 20) }
        // Wait for the helper to start instead of racing process launch.
        for _ in 0..<100 {
            if FileManager.default.fileExists(atPath: evidence.path) { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        task.cancel()
        do { _ = try await task.value; Issue.record("Cancelled OCR should not succeed") }
        catch { #expect(error is CancellationError) }
        let parts = try String(contentsOf: evidence, encoding: .utf8).components(separatedBy: "|")
        #expect(kill(try #require(Int32(parts[0])), 0) == -1)
        #expect(errno == ESRCH)
        #expect(!FileManager.default.fileExists(atPath: parts[1]))
    }

    @Test func multilingualAndRepeatedRealRecognition() async throws {
        let engine = OCRWorkerRunner()
        _ = try await engine.run(imageData: nil, languageHint: nil, timeout: 60)
        let samples = [
            ("Cheese OCR 123", "Helvetica", "en"),
            ("中文文字识别测试", "PingFangSC-Regular", "zh"),
            ("繁體中文辨識測試", "PingFangTC-Regular", "zh-Hant"),
            ("日本語の文字認識テスト", "HiraginoSans-W3", "ja"),
            ("한국어 문자 인식 테스트", "AppleSDGothicNeo-Regular", "ko"),
        ]
        for _ in 0..<3 {
            for (text, font, hint) in samples {
                let result = try await engine.run(imageData: fixture(text, font: font), languageHint: hint, timeout: 120)
                #expect(result.replacingOccurrences(of: " ", with: "") == text.replacingOccurrences(of: " ", with: ""))
            }
        }
        // Exercise the app's actual default: no language hint.
        for (text, font, _) in samples {
            let result = try await engine.run(imageData: fixture(text, font: font), languageHint: nil, timeout: 20)
            #expect(result.replacingOccurrences(of: " ", with: "") == text.replacingOccurrences(of: " ", with: ""))
        }
        // The original failures included very small captures.
        #expect(try await engine.run(imageData: fixture("Cheese 123", width: 200, height: 128), languageHint: "en", timeout: 20) == "Cheese 123")
        #expect(try await engine.run(imageData: fixture(""), languageHint: nil, timeout: 20) == "")
    }
}
