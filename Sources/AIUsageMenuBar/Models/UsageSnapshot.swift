import Foundation

struct UsageWindow: Codable, Equatable, Sendable {
    let title: String
    let usedPercent: Int
    let durationMinutes: Int
    /// `nil` means the rolling window has not started yet. Claude returns this
    /// for an unused five-hour window, so it is a valid state rather than a
    /// malformed response.
    let resetsAt: Date?

    var remainingPercent: Int {
        max(0, min(100, 100 - usedPercent))
    }
}

struct UsageSnapshot: Codable, Equatable, Sendable {
    let providerName: String
    let planName: String?
    let primary: UsageWindow
    let secondary: UsageWindow
    let fetchedAt: Date
}
