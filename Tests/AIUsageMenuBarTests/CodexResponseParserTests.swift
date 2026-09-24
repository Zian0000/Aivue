import Foundation
import Testing
@testable import AIUsageMenuBar

struct CodexResponseParserTests {
    @Test
    func parsesRateLimitResponse() throws {
        let line = #"{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":45,"windowDurationMins":300,"resetsAt":1790139936},"secondary":{"usedPercent":76,"windowDurationMins":10080,"resetsAt":1790559969},"planType":"plus"}}}"#
        let fetchedAt = Date(timeIntervalSince1970: 1_700_000_000)

        let parsedSnapshot = try CodexResponseParser.parseRateLimitsLine(line, fetchedAt: fetchedAt)
        let snapshot = try #require(parsedSnapshot)

        #expect(snapshot.providerName == "Codex")
        #expect(snapshot.planName == "plus")
        #expect(snapshot.primary.usedPercent == 45)
        #expect(snapshot.primary.remainingPercent == 55)
        #expect(snapshot.primary.durationMinutes == 300)
        #expect(snapshot.secondary.usedPercent == 76)
        #expect(snapshot.secondary.remainingPercent == 24)
        #expect(snapshot.secondary.durationMinutes == 10_080)
        #expect(snapshot.fetchedAt == fetchedAt)
    }

    @Test
    func ignoresNotifications() throws {
        let line = #"{"method":"account/updated","params":{"planType":"plus"}}"#
        let snapshot = try CodexResponseParser.parseRateLimitsLine(line)
        #expect(snapshot == nil)
    }

    @Test
    func clampsRemainingPercentage() {
        let window = UsageWindow(
            title: "Test",
            usedPercent: 125,
            durationMinutes: 300,
            resetsAt: .now
        )
        #expect(window.remainingPercent == 0)
    }

    @Test
    func classifiesExpiredLogin() {
        let line = #"{"id":2,"error":{"code":-32001,"message":"Authentication required; please log in"}}"#
        #expect(throws: UsageProviderError.self) {
            try CodexResponseParser.parseRateLimitsLine(line)
        }
    }

    @Test
    func rejectsMissingUsageWindows() {
        let line = #"{"id":2,"result":{"rateLimits":{"planType":"future_plan","primary":{"usedPercent":10}}}}"#
        #expect(throws: UsageProviderError.self) {
            try CodexResponseParser.parseRateLimitsLine(line)
        }
    }

    @Test
    func acceptsUnknownPlanAndClampsPercentages() throws {
        let line = #"{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":-4,"windowDurationMins":300,"resetsAt":1790139936},"secondary":{"usedPercent":140,"windowDurationMins":10080,"resetsAt":1790559969},"planType":"future_plan"}}}"#
        let snapshot = try #require(try CodexResponseParser.parseRateLimitsLine(line))
        #expect(snapshot.planName == "future_plan")
        #expect(snapshot.primary.usedPercent == 0)
        #expect(snapshot.secondary.usedPercent == 100)
    }
}
