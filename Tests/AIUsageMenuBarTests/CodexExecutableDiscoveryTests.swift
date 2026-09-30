import Foundation
import Testing
@testable import AIUsageMenuBar

struct CodexExecutableDiscoveryTests {
    @Test
    func findsCurrentChatGPTBundleLayout() throws {
        let app = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: app) }
        let executable = app.appendingPathComponent(
            "Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"
        )
        try makeExecutable(at: executable)

        #expect(CodexUsageProvider.findBundledCodex(appURL: app)?.standardizedFileURL == executable.standardizedFileURL)
    }

    @Test
    func findsCodexAfterBundleLayoutChanges() throws {
        let app = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: app) }
        let executable = app.appendingPathComponent("Contents/Resources/tools/cli/codex")
        try makeExecutable(at: executable)

        #expect(CodexUsageProvider.findBundledCodex(appURL: app)?.standardizedFileURL == executable.standardizedFileURL)
    }

    private func makeExecutable(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data().write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }
}
