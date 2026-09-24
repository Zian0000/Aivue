import Combine
import Foundation

@MainActor
final class UsageSettings: ObservableObject {
    private enum Key {
        static let showCodex = "showCodex"
        static let showClaude = "showClaude"
        static let refreshInterval = "refreshInterval"
        static let compactMenuBar = "compactMenuBar"
        static let lowUsageAlerts = "lowUsageAlerts"
    }

    private let defaults: UserDefaults

    @Published var showCodex: Bool {
        didSet { defaults.set(showCodex, forKey: Key.showCodex) }
    }

    @Published var showClaude: Bool {
        didSet { defaults.set(showClaude, forKey: Key.showClaude) }
    }

    @Published var refreshInterval: TimeInterval {
        didSet { defaults.set(refreshInterval, forKey: Key.refreshInterval) }
    }

    @Published var compactMenuBar: Bool {
        didSet { defaults.set(compactMenuBar, forKey: Key.compactMenuBar) }
    }

    @Published var lowUsageAlerts: Bool {
        didSet { defaults.set(lowUsageAlerts, forKey: Key.lowUsageAlerts) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showCodex = defaults.object(forKey: Key.showCodex) as? Bool ?? true
        showClaude = defaults.object(forKey: Key.showClaude) as? Bool ?? true
        let stored = defaults.double(forKey: Key.refreshInterval)
        refreshInterval = [60.0, 300.0, 600.0, 1800.0].contains(stored) ? stored : 60
        compactMenuBar = defaults.object(forKey: Key.compactMenuBar) as? Bool ?? false
        lowUsageAlerts = defaults.object(forKey: Key.lowUsageAlerts) as? Bool ?? false
    }
}
