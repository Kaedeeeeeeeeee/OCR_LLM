import Foundation
#if os(macOS)
import AppKit

enum NativeCaptureError: Error { case toolNotFound, canceled, failed(String) }

struct NativeScreencapture {
    static func captureSelectionToPNG() async throws -> Data? {
        // Find screencapture
        let candidatePaths = ["/usr/sbin/screencapture", "/usr/bin/screencapture", "/bin/screencapture", "/sbin/screencapture"]
        let tool = candidatePaths.first { FileManager.default.isExecutableFile(atPath: $0) } ?? "screencapture"

        // Temp path
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("QuickOCRLLM", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filename = "screencap_\(UUID().uuidString).png"
        let outURL = dir.appendingPathComponent(filename)

        // Run screencapture -i -s -o -x <path>
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: tool)
        proc.arguments = ["-i", "-s", "-o", "-x", outURL.path]

        let err = Pipe()
        proc.standardError = err
        let out = Pipe()
        proc.standardOutput = out

        try proc.run()
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            proc.terminationHandler = { _ in c.resume() }
        }

        // Exit code: 0 success, 1 canceled or failure
        if proc.terminationStatus != 0 {
            // If user cancels, file won't exist; return nil
            if !FileManager.default.fileExists(atPath: outURL.path) {
                #if DEBUG
                let errData = err.fileHandleForReading.readDataToEndOfFile()
                if let s = String(data: errData, encoding: .utf8), !s.isEmpty {
                    print("screencapture stderr: \(s)")
                }
                #endif
                return nil
            }
        }

        // Verify result
        guard let data = try? Data(contentsOf: outURL), data.count > 0 else {
            #if DEBUG
            let errData = err.fileHandleForReading.readDataToEndOfFile()
            if let s = String(data: errData, encoding: .utf8), !s.isEmpty {
                print("screencapture produced no data; stderr: \(s)")
            }
            #endif
            return nil
        }

        // Cleanup file
        try? FileManager.default.removeItem(at: outURL)
        return data
    }
}

#endif
