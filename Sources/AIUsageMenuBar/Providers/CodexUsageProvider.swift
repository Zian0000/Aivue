import Foundation

struct CodexUsageProvider: UsageProviding {
    private let executableURL: URL?
    private let timeout: TimeInterval

    init(executableURL: URL? = nil, timeout: TimeInterval = 15) {
        self.executableURL = executableURL
        self.timeout = timeout
    }

    func fetchUsage() async throws -> UsageSnapshot {
        let executable = try resolveExecutable()
        let timeout = timeout

        return try await Task.detached(priority: .utility) {
            try Self.runQuery(executable: executable, timeout: timeout)
        }.value
    }

    private func resolveExecutable() throws -> URL {
        if let executableURL, FileManager.default.isExecutableFile(atPath: executableURL.path) {
            return executableURL
        }

        let candidates = [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ]

        if let path = candidates.first(where: FileManager.default.isExecutableFile(atPath:)) {
            return URL(fileURLWithPath: path)
        }

        throw UsageProviderError.codexNotFound
    }

    private static func runQuery(executable: URL, timeout: TimeInterval) throws -> UsageSnapshot {
        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let collector = CodexOutputCollector()
        let responseReady = DispatchSemaphore(value: 0)

        process.executableURL = executable
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw UsageProviderError.launchFailed(error.localizedDescription)
        }

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty || collector.consume(data) {
                responseReady.signal()
            }
        }

        let requests = [
            #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{"name":"ai-usage-menu-bar","version":"0.1.0"},"capabilities":{"experimentalApi":true}}}"#,
            #"{"jsonrpc":"2.0","method":"initialized"}"#,
            #"{"jsonrpc":"2.0","id":2,"method":"account/rateLimits/read","params":{"excludeResetCreditDetails":true,"supportsLunaReserve":false}}"#
        ].joined(separator: "\n") + "\n"

        inputPipe.fileHandleForWriting.write(Data(requests.utf8))

        defer {
            outputPipe.fileHandleForReading.readabilityHandler = nil
            inputPipe.fileHandleForWriting.closeFile()
            if process.isRunning {
                process.terminate()
            }
        }

        guard responseReady.wait(timeout: .now() + timeout) == .success else {
            throw UsageProviderError.timedOut
        }

        if let result = collector.result {
            return try result.get()
        }

        if !process.isRunning {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            if let message = String(data: errorData, encoding: .utf8), !message.isEmpty {
                throw UsageProviderError.launchFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        throw UsageProviderError.timedOut
    }
}

private final class CodexOutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private var storedResult: Result<UsageSnapshot, Error>?

    var result: Result<UsageSnapshot, Error>? {
        lock.withLock { storedResult }
    }

    /// Returns true after the rate-limit response or an app-server error is found.
    func consume(_ data: Data) -> Bool {
        lock.withLock {
            guard storedResult == nil else { return true }
            buffer.append(data)

            while let newline = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer[..<newline]
                buffer.removeSubrange(...newline)

                guard let line = String(data: lineData, encoding: .utf8) else {
                    continue
                }

                do {
                    if let snapshot = try CodexResponseParser.parseRateLimitsLine(line) {
                        storedResult = .success(snapshot)
                        return true
                    }
                } catch {
                    storedResult = .failure(error)
                    return true
                }
            }

            return false
        }
    }
}
