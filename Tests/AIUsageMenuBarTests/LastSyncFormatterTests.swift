import Foundation
import Testing
@testable import AIUsageMenuBar

struct LastSyncFormatterTests {
    @Test func secondsWithinFirstMinute() {
        let now = Date(timeIntervalSince1970: 10_000)
        #expect(LastSyncFormatter.string(fetchedAt: now, now: now) == "0秒鐘前")
        #expect(LastSyncFormatter.string(fetchedAt: now.addingTimeInterval(-59), now: now) == "59秒鐘前")
    }

    @Test func minutesBeforeOneHour() {
        let now = Date(timeIntervalSince1970: 10_000)
        #expect(LastSyncFormatter.string(fetchedAt: now.addingTimeInterval(-60), now: now) == "1分鐘前")
        #expect(LastSyncFormatter.string(fetchedAt: now.addingTimeInterval(-3_599), now: now) == "59分鐘前")
    }

    @Test func twentyFourHourClockAfterOneHour() {
        let fetchedAt = Date(timeIntervalSince1970: 10_000)
        let expected = DateFormatter()
        expected.locale = Locale(identifier: "en_US_POSIX")
        expected.dateFormat = "HH:mm"
        #expect(LastSyncFormatter.string(fetchedAt: fetchedAt, now: fetchedAt.addingTimeInterval(3_600)) == expected.string(from: fetchedAt))
    }
}
