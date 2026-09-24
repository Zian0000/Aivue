import Foundation

enum CodexResponseParser {
    static func parseRateLimitsLine(_ line: String, fetchedAt: Date = Date()) throws -> UsageSnapshot? {
        guard let data = line.data(using: .utf8),
              let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        if let error = envelope["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Unknown app-server error"
            let normalized = message.lowercased()
            if normalized.contains("login") || normalized.contains("log in")
                || normalized.contains("auth") || normalized.contains("unauthorized") {
                throw UsageProviderError.authenticationRequired("Codex")
            }
            throw UsageProviderError.serverError(message)
        }

        guard (envelope["id"] as? Int) == 2 else {
            return nil
        }

        guard let result = envelope["result"] as? [String: Any],
              let limits = result["rateLimits"] as? [String: Any],
              let primary = parseWindow(limits["primary"], title: "5 小時區段"),
              let secondary = parseWindow(limits["secondary"], title: "7 天總額度")
        else {
            throw UsageProviderError.invalidResponse
        }

        return UsageSnapshot(
            providerName: "Codex",
            planName: limits["planType"] as? String,
            primary: primary,
            secondary: secondary,
            fetchedAt: fetchedAt
        )
    }

    private static func parseWindow(_ value: Any?, title: String) -> UsageWindow? {
        guard let object = value as? [String: Any],
              let usedPercent = number(object["usedPercent"]),
              let durationMinutes = number(object["windowDurationMins"]),
              let resetsAt = number(object["resetsAt"])
        else {
            return nil
        }

        return UsageWindow(
            title: title,
            usedPercent: max(0, min(100, Int(usedPercent.rounded()))),
            durationMinutes: Int(durationMinutes.rounded()),
            resetsAt: Date(timeIntervalSince1970: resetsAt)
        )
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        return value as? Double
    }
}
