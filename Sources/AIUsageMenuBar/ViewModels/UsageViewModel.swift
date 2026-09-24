@preconcurrency import AppKit
import Combine
import Foundation
import Network

@MainActor
final class UsageViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case loaded(UsageSnapshot)
        case failed(message: String, cached: UsageSnapshot?)
    }

    @Published private(set) var codexState: State
    @Published private(set) var claudeState: State
    @Published private(set) var isRefreshingCodex = false
    @Published private(set) var isRefreshingClaude = false
    @Published private(set) var isOffline = false

    private let codexProvider: any UsageProviding
    let claudeSession: ClaudeSessionController
    let settings: UsageSettings
    private let cache: UsageCacheStore
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "AIUsageMenuBar.NetworkMonitor")
    private var codexPollingTask: Task<Void, Never>?
    private var claudePollingTask: Task<Void, Never>?
    private var settingsCancellables = Set<AnyCancellable>()
    private var wakeObserver: NSObjectProtocol?
    private var codexFailures = 0
    private var claudeFailures = 0
    private let lowUsageNotifier = LowUsageNotifier()

    init(
        codexProvider: any UsageProviding,
        claudeSession: ClaudeSessionController,
        settings: UsageSettings = UsageSettings(),
        cache: UsageCacheStore = UsageCacheStore()
    ) {
        self.codexProvider = codexProvider
        self.claudeSession = claudeSession
        self.settings = settings
        self.cache = cache

        let cachedCodex = cache.load(.codex)
        let cachedClaude = cache.load(.claude)
        codexState = cachedCodex.map {
            .failed(message: "正在更新已儲存的資料…", cached: $0)
        } ?? .loading
        claudeState = cachedClaude.map {
            .failed(message: "正在更新已儲存的資料…", cached: $0)
        } ?? .failed(message: "Claude 尚未連結。", cached: nil)

        startObservers()
        restartPolling()
        claudeSession.setConnectionHandler { [weak self] in
            Task { @MainActor [weak self] in await self?.refreshClaude() }
        }
    }

    deinit {
        codexPollingTask?.cancel()
        claudePollingTask?.cancel()
        networkMonitor.cancel()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    var codexSnapshot: UsageSnapshot? { snapshot(from: codexState) }
    var claudeSnapshot: UsageSnapshot? { snapshot(from: claudeState) }

    var menuBarText: String {
        var pieces: [String] = []
        if settings.showCodex {
            pieces.append(codexSnapshot.map { "C \($0.primary.remainingPercent)%" } ?? "C --%")
        }
        if settings.showClaude {
            pieces.append(claudeSnapshot.map { "A \($0.primary.remainingPercent)%" } ?? "A --%")
        }
        return pieces.isEmpty ? "AI --%" : pieces.joined(separator: "  ")
    }

    var menuBarSymbol: String {
        if isOffline { return "wifi.slash" }
        if case .failed = codexState, case .failed = claudeState {
            return "exclamationmark.triangle"
        }
        return "sparkles"
    }

    func isStale(_ snapshot: UsageSnapshot, now: Date = Date()) -> Bool {
        now.timeIntervalSince(snapshot.fetchedAt) > max(120, settings.refreshInterval * 2)
    }

    func refreshAll() async {
        async let codex: Void = settings.showCodex ? refreshCodex() : ()
        async let claude: Void = settings.showClaude ? refreshClaude() : ()
        _ = await (codex, claude)
    }

    func refreshCodex() async {
        guard !isRefreshingCodex else { return }
        isRefreshingCodex = true
        defer { isRefreshingCodex = false }
        do {
            let snapshot = try await codexProvider.fetchUsage()
            codexState = .loaded(snapshot)
            codexFailures = 0
            try? cache.save(snapshot, for: .codex)
            await lowUsageNotifier.check(snapshot, provider: "Codex", enabled: settings.lowUsageAlerts)
        } catch {
            codexFailures += 1
            codexState = .failed(message: displayMessage(for: error), cached: codexSnapshot)
        }
    }

    func refreshClaude() async {
        guard !isRefreshingClaude else { return }
        guard claudeSession.isConnected else {
            claudeState = .failed(message: "Claude 尚未連結。", cached: claudeSnapshot)
            return
        }
        isRefreshingClaude = true
        defer { isRefreshingClaude = false }
        do {
            let snapshot = try await claudeSession.fetchUsage()
            claudeState = .loaded(snapshot)
            claudeFailures = 0
            try? cache.save(snapshot, for: .claude)
            await lowUsageNotifier.check(snapshot, provider: "Claude", enabled: settings.lowUsageAlerts)
        } catch {
            claudeFailures += 1
            Diagnostics.log("refreshClaude 失敗: \(error.localizedDescription)")
            claudeState = .failed(message: displayMessage(for: error), cached: claudeSnapshot)
        }
    }

    func disconnectClaude() async {
        await claudeSession.disconnect()
        claudeState = .failed(message: "Claude 尚未連結。", cached: claudeSnapshot)
    }

    func quit() { NSApplication.shared.terminate(nil) }

    private func snapshot(from state: State) -> UsageSnapshot? {
        switch state {
        case .loading: nil
        case .loaded(let snapshot): snapshot
        case .failed(_, let cached): cached
        }
    }

    private func displayMessage(for error: Error) -> String {
        isOffline ? "網路已斷線，顯示上次成功資料。" : error.localizedDescription
    }

    private func retryDelay(failures: Int) -> TimeInterval {
        guard failures > 0 else { return settings.refreshInterval }
        let backoff: [TimeInterval] = [60, 120, 300, 600]
        return backoff[min(failures - 1, backoff.count - 1)]
    }

    private func restartPolling() {
        codexPollingTask?.cancel()
        claudePollingTask?.cancel()
        codexPollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                if settings.showCodex { await refreshCodex() }
                try? await Task.sleep(for: .seconds(retryDelay(failures: codexFailures)))
            }
        }
        claudePollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                if settings.showClaude { await refreshClaude() }
                try? await Task.sleep(for: .seconds(retryDelay(failures: claudeFailures)))
            }
        }
    }

    private func startObservers() {
        settings.$refreshInterval.dropFirst().sink { [weak self] _ in
            self?.objectWillChange.send()
            self?.restartPolling()
        }.store(in: &settingsCancellables)
        settings.$showCodex.combineLatest(settings.$showClaude).dropFirst().sink { [weak self] _, _ in
            self?.objectWillChange.send()
            self?.restartPolling()
        }.store(in: &settingsCancellables)
        settings.$compactMenuBar.dropFirst().sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &settingsCancellables)
        settings.$lowUsageAlerts.dropFirst().sink { [weak self] enabled in
            guard let self, enabled else { return }
            Task { @MainActor in
                if let snapshot = self.codexSnapshot {
                    await self.lowUsageNotifier.check(snapshot, provider: "Codex", enabled: true)
                }
                if let snapshot = self.claudeSnapshot {
                    await self.lowUsageNotifier.check(snapshot, provider: "Claude", enabled: true)
                }
            }
        }.store(in: &settingsCancellables)

        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasOffline = isOffline
                isOffline = path.status != .satisfied
                if wasOffline && !isOffline {
                    Diagnostics.log("網路已恢復，立即更新用量")
                    await refreshAll()
                }
            }
        }
        networkMonitor.start(queue: networkQueue)

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                Diagnostics.log("Mac 已喚醒，立即更新用量")
                await self?.refreshAll()
            }
        }
    }
}
