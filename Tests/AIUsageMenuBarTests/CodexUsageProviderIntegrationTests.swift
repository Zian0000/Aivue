import Foundation
import Testing
@testable import AIUsageMenuBar

struct CodexUsageProviderIntegrationTests {
    @Test
    func readsLiveUsageFromLocalCodexLogin() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LIVE_CODEX_USAGE_TEST"] == "1" else {
            return
        }

        let snapshot = try await CodexUsageProvider(timeout: 20).fetchUsage()

        #expect(snapshot.providerName == "Codex")
        #expect((0...100).contains(snapshot.primary.usedPercent))
        #expect((0...100).contains(snapshot.secondary.usedPercent))
        #expect(snapshot.primary.durationMinutes == 300)
        #expect(snapshot.secondary.durationMinutes == 10_080)
        #expect(snapshot.primary.resetsAt.map { $0 > snapshot.fetchedAt } == true)
        #expect(snapshot.secondary.resetsAt.map { $0 > snapshot.fetchedAt } == true)
    }
}
