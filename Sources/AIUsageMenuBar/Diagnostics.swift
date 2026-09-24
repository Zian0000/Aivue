import AppKit
import Foundation

@MainActor
enum Diagnostics {
    private static var didInitializeLog = false
    static let logURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("AIUsageMenuBar-diagnostics.log")

    static func log(_ message: String) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        fputs(line, stderr)

        guard let data = line.data(using: .utf8) else { return }
        if !didInitializeLog {
            didInitializeLog = true
            try? data.write(to: logURL, options: .atomic)
            return
        }
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: data)
            return
        }
        do {
            let handle = try FileHandle(forWritingTo: logURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
        } catch {
            fputs("Diagnostics write failed: \(error)\n", stderr)
        }
    }

    /// Removes query strings and fragments, which can contain short-lived
    /// OAuth codes or other sensitive navigation state.
    static func safeURL(_ url: URL?) -> String {
        guard let url else { return "nil" }
        var components = URLComponents()
        components.scheme = url.scheme
        components.host = url.host
        components.port = url.port
        components.path = url.path
        return components.url?.absoluteString ?? "redacted-url"
    }

    static func copyToPasteboard() {
        let contents = (try? String(contentsOf: logURL, encoding: .utf8))
            ?? "尚無診斷紀錄"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(contents, forType: .string)
        log("診斷紀錄已複製到剪貼簿")
    }
}
