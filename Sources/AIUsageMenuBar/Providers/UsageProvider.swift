import Foundation

protocol UsageProviding: Sendable {
    func fetchUsage() async throws -> UsageSnapshot
}

enum UsageProviderError: LocalizedError, Sendable {
    case codexNotFound
    case launchFailed(String)
    case timedOut
    case invalidResponse
    case serverError(String)
    case authenticationRequired(String)

    var errorDescription: String? {
        switch self {
        case .codexNotFound:
            return "找不到 Codex，請先安裝 ChatGPT Desktop 或 Codex CLI。"
        case .launchFailed(let reason):
            return "無法啟動 Codex：\(reason)"
        case .timedOut:
            return "Codex 用量查詢逾時。"
        case .invalidResponse:
            return "Codex 回傳了無法辨識的用量資料。"
        case .serverError(let message):
            return "Codex 查詢失敗：\(message)"
        case .authenticationRequired(let provider):
            return "\(provider) 登入已失效，請重新登入。"
        }
    }
}
