import Foundation
import ImageIO
import os
import Darwin

/// Local Apple Vision OCR in a restartable, sandbox-inheriting helper.
/// Model failures and unresponsive native work cannot poison the menu bar app.
final class VisionOCRProvider: OCRProvider {
    let name = "Vision (Local)"

    static func prewarmInBackground() {
        Task(priority: .utility) { await VisionOCRService.shared.prewarm() }
    }

    func recognize(imageData: Data, mode: OCRMode, languageHint: String?, timeout: TimeInterval) async throws -> String {
        try await VisionOCRService.shared.recognize(imageData: imageData, languageHint: languageHint, timeout: timeout)
    }
}

private actor VisionOCRService {
    static let shared = VisionOCRService()
    private var warmup: Task<Void, Never>?
    private let runner = OCRWorkerRunner()

    func prewarm() async {
        guard warmup == nil else { return }
        let task = Task {
            do { _ = try await runner.run(imageData: nil, languageHint: nil, timeout: 60) }
            catch { OCRWorkerRunner.logger.error("Vision warm-up failed: \(error.localizedDescription, privacy: .public)") }
        }
        warmup = task
        await task.value
    }

    func recognize(imageData: Data, languageHint: String?, timeout: TimeInterval) async throws -> String {
        // Avoid compiling the same cold models twice while startup warm-up is running.
        await warmup?.value
        return try await runner.run(imageData: imageData, languageHint: languageHint, timeout: timeout)
    }
}

nonisolated struct OCRWorkerResponse: Decodable, Sendable {
    struct Failure: Decodable, Sendable {
        let domain: String
        let code: Int
    }
    let text: String?
    let errors: [Failure]?
    let message: String?

    var canRetry: Bool {
        errors?.contains {
            ($0.domain == "TextRecognition.CRImageReaderError" && $0.code == 1)
                || ($0.domain == "com.apple.appleneuralengine" && $0.code == 16)
        } == true
    }
}

nonisolated struct OCRWorkerRunner: Sendable {
    nonisolated static let logger = Logger(subsystem: "com.cheeseocr.app", category: "OCR")
    var workerURL: URL? = Bundle.main.url(forAuxiliaryExecutable: "CheeseOCRWorker")
    var workerEnvironment: [String: String] = [:]
    private let session = OCRWorkerProcess()

    func run(imageData: Data?, languageHint: String?, timeout: TimeInterval) async throws -> String {
        guard let workerURL else { throw OCRProviderError.requestFailed("OCR helper is missing. Please reinstall Cheese OCR.") }
        if let imageData {
            guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
                  CGImageSourceGetCount(source) > 0 else { throw OCRProviderError.invalidResponse }
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CheeseOCR-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        // The helper has finished this request (or was terminated) before cleanup.
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("input.png")
        if let imageData { try imageData.write(to: input, options: .atomic) }
        let requestID = UUID().uuidString
        let started = ProcessInfo.processInfo.systemUptime
        // A normal request has the caller's budget. Model recovery gets one bounded
        // cold-start allowance, since recompilation on macOS 27 can exceed 20s.
        var deadline = started + max(0, timeout)
        for attempt in 1...2 {
            try Task.checkCancellation()
            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else { throw OCRProviderError.timedOut }
            let output = directory.appendingPathComponent("result-\(attempt).json")
            Self.logger.info("OCR request \(requestID, privacy: .public) attempt \(attempt) started (warmup=\(imageData == nil))")
            let status = try await session.run(
                executable: workerURL,
                arguments: [imageData == nil ? "--warmup" : input.path, output.path, languageHint ?? ""],
                environment: workerEnvironment,
                timeout: remaining
            )
            if status != 0 {
                Self.logger.error("OCR request \(requestID, privacy: .public) worker exited with status \(status)")
                if attempt == 1 {
                    deadline = max(deadline, ProcessInfo.processInfo.systemUptime + 60)
                    continue
                }
                throw OCRProviderError.requestFailed("OCR engine stopped unexpectedly. Please try again.")
            }
            guard let data = try? Data(contentsOf: output),
                  let response = try? JSONDecoder().decode(OCRWorkerResponse.self, from: data) else {
                throw OCRProviderError.invalidResponse
            }
            if let text = response.text {
                Self.logger.info("OCR request \(requestID, privacy: .public) completed in \(ProcessInfo.processInfo.systemUptime - started, format: .fixed(precision: 3)) seconds (attempt \(attempt))")
                return text
            }
            let codes = response.errors?.map { "\($0.domain):\($0.code)" }.joined(separator: ",") ?? "unknown"
            Self.logger.error("OCR request \(requestID, privacy: .public) failed: \(codes, privacy: .public)")
            if response.canRetry {
                await session.reset()
                if attempt == 1 {
                    Self.logger.notice("Retrying OCR request \(requestID, privacy: .public) with a fresh Vision process")
                    deadline = max(deadline, ProcessInfo.processInfo.systemUptime + 60)
                    continue
                }
            }
            throw OCRProviderError.requestFailed(response.message ?? "OCR engine failed. Please try again.")
        }
        throw OCRProviderError.invalidResponse
    }
}

/// Serializes requests to one helper. Process state belongs to this queue; only
/// the per-request result is shared with the I/O and cancellation callbacks.
private nonisolated final class OCRWorkerProcess: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.cheeseocr.worker-process", qos: .userInitiated)
    private var process: Process?
    private var exited: DispatchGroup?
    private var input: Pipe?
    private var output: Pipe?

    private nonisolated final class Reply: @unchecked Sendable {
        enum Result { case ready, exited(Int32), cancelled }
        let semaphore = DispatchSemaphore(value: 0)
        private let lock = NSLock()
        private var result: Result?
        func resolve(_ value: Result) {
            lock.lock()
            defer { lock.unlock() }
            if result == nil { result = value; semaphore.signal() }
        }
        var value: Result? {
            lock.lock()
            defer { lock.unlock() }
            return result
        }
    }

    func run(executable: URL, arguments: [String], environment: [String: String], timeout: TimeInterval) async throws -> Int32 {
        let reply = Reply()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    do {
                        continuation.resume(returning: try self.execute(executable: executable, arguments: arguments,
                                                                       environment: environment, timeout: timeout, reply: reply))
                    } catch { continuation.resume(throwing: error) }
                }
            }
        } onCancel: { reply.resolve(.cancelled) }
    }

    private func execute(executable: URL, arguments: [String], environment: [String: String], timeout: TimeInterval, reply: Reply) throws -> Int32 {
        if case .cancelled = reply.value { throw CancellationError() }
        if process?.isRunning != true {
            stop()
            let child = Process()
            let inputPipe = Pipe()
            let outputPipe = Pipe()
            // A helper can exit between isRunning and write. EPIPE must become
            // a request error, not a SIGPIPE that terminates the menu bar app.
            _ = fcntl(inputPipe.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
            child.executableURL = executable
            child.environment = ProcessInfo.processInfo.environment.merging(environment) { _, value in value }
            child.standardInput = inputPipe
            child.standardOutput = outputPipe
            child.standardError = FileHandle.nullDevice
            let exited = DispatchGroup()
            exited.enter()
            child.terminationHandler = { _ in exited.leave() }
            try child.run()
            process = child
            self.exited = exited
            input = inputPipe
            output = outputPipe
        }
        guard process != nil, let input, let output else { throw OCRProviderError.invalidResponse }
        output.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { reply.resolve(.ready) }
            else { reply.resolve(.exited(70)) }
        }
        defer {
            output.fileHandleForReading.readabilityHandler = nil
        }
        do {
            var command = try JSONEncoder().encode(arguments)
            command.append(0x0a)
            try input.fileHandleForWriting.write(contentsOf: command)
        } catch {
            stop()
            return 70
        }
        if reply.semaphore.wait(timeout: .now() + timeout) == .timedOut {
            stop()
            throw OCRProviderError.timedOut
        }
        switch reply.value {
        case .ready: return 0
        case .exited(let status): stop(); return status == 0 ? 70 : status
        case .cancelled: stop(); throw CancellationError()
        case nil: stop(); throw OCRProviderError.invalidResponse
        }
    }

    func reset() async {
        await withCheckedContinuation { continuation in
            queue.async { self.stop(); continuation.resume() }
        }
    }

    private func stop() {
        output?.fileHandleForReading.readabilityHandler = nil
        if let process, process.isRunning {
            // SIGKILL makes the deadline independent of uncooperative native code.
            kill(process.processIdentifier, SIGKILL)
            // Foundation's waitUntilExit can hang when called from a different
            // run loop. The launch-time termination notification has a bound.
            _ = exited?.wait(timeout: .now() + 2)
        }
        try? input?.fileHandleForWriting.close()
        try? output?.fileHandleForReading.close()
        process = nil
        exited = nil
        input = nil
        output = nil
    }

    deinit {
        // Deinitialization may run on Swift's cooperative executor. Never block
        // it waiting for Process/CFRunLoop; Foundation reaps the killed child.
        output?.fileHandleForReading.readabilityHandler = nil
        if let process, process.isRunning { kill(process.processIdentifier, SIGKILL) }
        try? input?.fileHandleForWriting.close()
        try? output?.fileHandleForReading.close()
    }
}
