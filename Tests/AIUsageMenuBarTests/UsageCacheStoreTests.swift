import Foundation
import Testing
@testable import AIUsageMenuBar

struct UsageCacheStoreTests {
    @Test
    func persistsBothProvidersWithoutOverwritingEachOther() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = UsageCacheStore(fileURL: directory.appendingPathComponent("cache.json"))
        let codex = snapshot(provider: "Codex", used: 20)
        let claude = snapshot(provider: "Claude", used: 35)

        try store.save(codex, for: .codex)
        try store.save(claude, for: .claude)

        #expect(store.load(.codex) == codex)
        #expect(store.load(.claude) == claude)
    }

    @Test
    func corruptedCacheFailsClosed() throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try Data("not-json".utf8).write(to: file)
        #expect(UsageCacheStore(fileURL: file).load(.codex) == nil)
    }

    private func snapshot(provider: String, used: Int) -> UsageSnapshot {
        UsageSnapshot(
            providerName: provider,
            planName: "test",
            primary: UsageWindow(
                title: "primary",
                usedPercent: used,
                durationMinutes: 300,
                resetsAt: Date(timeIntervalSince1970: 2_000_000_000)
            ),
            secondary: UsageWindow(
                title: "secondary",
                usedPercent: used + 1,
                durationMinutes: 10_080,
                resetsAt: Date(timeIntervalSince1970: 2_000_100_000)
            ),
            fetchedAt: Date(timeIntervalSince1970: 1_900_000_000)
        )
    }
}
