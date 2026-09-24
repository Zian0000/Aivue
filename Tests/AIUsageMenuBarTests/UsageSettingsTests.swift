import Foundation
import Testing
@testable import AIUsageMenuBar

@MainActor
struct UsageSettingsTests {
    @Test
    func persistsDisplayAndRefreshPreferences() throws {
        let suite = "AIUsageMenuBarTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = UsageSettings(defaults: defaults)
        settings.showCodex = false
        settings.showClaude = true
        settings.refreshInterval = 300
        settings.compactMenuBar = true
        settings.lowUsageAlerts = true

        let restored = UsageSettings(defaults: defaults)
        #expect(restored.showCodex == false)
        #expect(restored.showClaude == true)
        #expect(restored.refreshInterval == 300)
        #expect(restored.compactMenuBar)
        #expect(restored.lowUsageAlerts)
    }

    @Test
    func rejectsUnsupportedStoredInterval() throws {
        let suite = "AIUsageMenuBarTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(17.0, forKey: "refreshInterval")
        #expect(UsageSettings(defaults: defaults).refreshInterval == 60)
    }

    @Test
    func supportsFinalSyncIntervals() throws {
        let suite = "AIUsageMenuBarTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        for interval in [60.0, 300.0, 600.0, 1800.0] {
            defaults.set(interval, forKey: "refreshInterval")
            #expect(UsageSettings(defaults: defaults).refreshInterval == interval)
        }
    }

    @Test
    func lowUsageThresholdIsStrictlyBelowFiftyPercent() {
        #expect(LowUsageNotifier.shouldNotify(remainingPercent: 49))
        #expect(!LowUsageNotifier.shouldNotify(remainingPercent: 50))
    }
}
