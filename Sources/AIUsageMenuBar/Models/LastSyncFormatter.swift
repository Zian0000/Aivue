import Foundation

enum LastSyncFormatter {
    static func string(fetchedAt: Date, now: Date) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(fetchedAt)))
        if elapsed < 60 { return "\(elapsed)秒鐘前" }
        if elapsed < 3_600 { return "\(elapsed / 60)分鐘前" }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: fetchedAt)
    }
}
