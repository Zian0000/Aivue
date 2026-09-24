import Foundation

struct UsageCacheStore: Sendable {
    private struct Payload: Codable {
        var codex: UsageSnapshot?
        var claude: UsageSnapshot?
    }

    enum Provider: String, Sendable {
        case codex
        case claude
    }

    let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
            self.fileURL = base
                .appendingPathComponent("AIUsageMenuBar", isDirectory: true)
                .appendingPathComponent("usage-cache.json")
        }
    }

    func load(_ provider: Provider) -> UsageSnapshot? {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return nil }
        return provider == .codex ? payload.codex : payload.claude
    }

    func save(_ snapshot: UsageSnapshot, for provider: Provider) throws {
        let existing: Payload
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(Payload.self, from: data) {
            existing = decoded
        } else {
            existing = Payload()
        }

        var payload = existing
        switch provider {
        case .codex: payload.codex = snapshot
        case .claude: payload.claude = snapshot
        }

        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(payload).write(to: fileURL, options: .atomic)
    }
}
