import Foundation

enum ClaudeResponseParser {
    static func parseUsageJSON(_ json: String, fetchedAt: Date = Date()) throws -> UsageSnapshot {
        guard let data = json.data(using: .utf8),
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw ClaudeUsageError.invalidResponse
        }

        if let error = root["error"] as? String {
            if error == "not_authenticated" {
                throw ClaudeUsageError.notConnected
            }
            throw ClaudeUsageError.requestFailed(error)
        }

        let usage = root["usage"] as? [String: Any] ?? root
        guard let primary = parseWindow(
            usage,
            keys: ["five_hour", "current_session", "session"],
            title: "目前區段"
        ), let secondary = parseWindow(
            usage,
            keys: ["seven_day", "weekly_all", "week"],
            title: "本週總額度"
        ) else {
            throw ClaudeUsageError.invalidResponse
        }

        return UsageSnapshot(
            providerName: "Claude",
            planName: root["planName"] as? String,
            primary: primary,
            secondary: secondary,
            fetchedAt: fetchedAt
        )
    }

    private static func parseWindow(
        _ usage: [String: Any],
        keys: [String],
        title: String
    ) -> UsageWindow? {
        guard let object = keys.lazy.compactMap({ usage[$0] as? [String: Any] }).first,
              let utilization = number(object["utilization"])
        else {
            return nil
        }

        let resetsAt: Date?
        if object["resets_at"] is NSNull || object["resets_at"] == nil {
            guard utilization == 0 else { return nil }
            resetsAt = nil
        } else if let resetsAtString = object["resets_at"] as? String,
                  let parsedDate = parseDate(resetsAtString) {
            resetsAt = parsedDate
        } else {
            return nil
        }

        return UsageWindow(
            title: title,
            usedPercent: max(0, min(100, Int(utilization.rounded()))),
            durationMinutes: title == "目前區段" ? 300 : 10_080,
            resetsAt: resetsAt
        )
    }

    private static func number(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue ?? value as? Double
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

enum ClaudeUsageError: LocalizedError, Sendable {
    case notConnected
    case pageNotReady
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            "Claude 尚未連結，請先登入帳號。"
        case .pageNotReady:
            "Claude 頁面尚未載入完成。"
        case .invalidResponse:
            "Claude 回傳了無法辨識的用量資料。"
        case .requestFailed(let message):
            "Claude 查詢失敗：\(message)"
        }
    }
}
