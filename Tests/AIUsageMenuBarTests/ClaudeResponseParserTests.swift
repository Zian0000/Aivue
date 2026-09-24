import Foundation
import Testing
@testable import AIUsageMenuBar

struct ClaudeResponseParserTests {
    @Test
    func parsesClaudeUsageWindows() throws {
        let json = #"{"usage":{"five_hour":{"utilization":15,"resets_at":"2026-09-23T07:20:00.000Z"},"seven_day":{"utilization":6,"resets_at":"2026-09-28T08:00:00.000Z"}},"planName":"pro"}"#
        let fetchedAt = Date(timeIntervalSince1970: 1_700_000_000)

        let snapshot = try ClaudeResponseParser.parseUsageJSON(json, fetchedAt: fetchedAt)

        #expect(snapshot.providerName == "Claude")
        #expect(snapshot.planName == "pro")
        #expect(snapshot.primary.usedPercent == 15)
        #expect(snapshot.primary.remainingPercent == 85)
        #expect(snapshot.secondary.usedPercent == 6)
        #expect(snapshot.secondary.remainingPercent == 94)
        #expect(snapshot.primary.durationMinutes == 300)
        #expect(snapshot.secondary.durationMinutes == 10_080)
    }

    @Test
    func reportsDisconnectedSession() {
        #expect(throws: ClaudeUsageError.self) {
            try ClaudeResponseParser.parseUsageJSON(#"{"error":"not_authenticated"}"#)
        }
    }

    @Test
    func supportsAliasFieldsAndUnknownPlan() throws {
        let json = #"{"usage":{"current_session":{"utilization":12.6,"resets_at":"2026-09-23T15:20:00+08:00"},"weekly_all":{"utilization":101,"resets_at":"2026-09-28T16:00:00+08:00"}},"planName":"future_tier"}"#
        let snapshot = try ClaudeResponseParser.parseUsageJSON(json)
        #expect(snapshot.planName == "future_tier")
        #expect(snapshot.primary.usedPercent == 13)
        #expect(snapshot.secondary.usedPercent == 100)
        #expect(snapshot.primary.resetsAt == Date(timeIntervalSince1970: 1_790_148_000))
    }

    @Test
    func parsesDatesWithAndWithoutFractionalSeconds() throws {
        let json = #"{"five_hour":{"utilization":0,"resets_at":"2026-09-23T07:20:00Z"},"seven_day":{"utilization":0,"resets_at":"2026-09-28T08:00:00.123Z"}}"#
        let snapshot = try ClaudeResponseParser.parseUsageJSON(json)
        #expect(snapshot.primary.resetsAt?.timeIntervalSince1970 == 1_790_148_000)
        #expect(snapshot.secondary.resetsAt?.timeIntervalSince1970 == 1_790_582_400.123)
    }

    @Test
    func reportsUnknownServerFailure() {
        #expect(throws: ClaudeUsageError.self) {
            try ClaudeResponseParser.parseUsageJSON(#"{"error":"usage_http_503"}"#)
        }
    }

    @Test
    func rejectsMissingResetTime() {
        let json = #"{"usage":{"five_hour":{"utilization":15},"seven_day":{"utilization":6,"resets_at":"2026-09-28T08:00:00Z"}}}"#
        #expect(throws: ClaudeUsageError.self) {
            try ClaudeResponseParser.parseUsageJSON(json)
        }
    }

    @Test
    func acceptsInactiveWindowWithoutResetTime() throws {
        let json = #"{"usage":{"five_hour":{"utilization":0,"resets_at":null},"seven_day":{"utilization":9,"resets_at":"2026-09-28T08:00:00Z"}},"planName":"pro"}"#
        let snapshot = try ClaudeResponseParser.parseUsageJSON(json)

        #expect(snapshot.primary.usedPercent == 0)
        #expect(snapshot.primary.resetsAt == nil)
        #expect(snapshot.secondary.usedPercent == 9)
    }
}
