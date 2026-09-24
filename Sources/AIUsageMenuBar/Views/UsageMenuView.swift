import AppKit
import SwiftUI

private enum UsageTheme {
    static let surface = Color(hex: 0x1B1E24)
    static let raised = Color(hex: 0x242831)
    static let hover = Color(hex: 0x303642)
    static let border = Color(hex: 0x3A404B)
    static let primaryText = Color(hex: 0xF3F4F6)
    static let secondaryText = Color(hex: 0xA8AFBA)
    static let blue = Color(hex: 0x9EBDE3)
    static let orange = Color(hex: 0xF6B672)
    static let warning = Color(hex: 0xFF9F43)
    static let red = Color(hex: 0xFF5F57)
    static let green = Color(hex: 0x45C97A)
}

private enum UsageFont {
    static func regular(_ size: CGFloat) -> Font { .custom("Inter", size: size) }
    static func bold(_ size: CGFloat) -> Font { .custom("Inter", size: size).weight(.bold) }
}

@MainActor enum UsageLogos {
    static let chatGPT = load("FigmaChatGPTPopover")
    static let claude = load("FigmaClaudePopover")
    static let menuBarAivue = load("FigmaAivueMark")
    static let menuBarOffline = load("FigmaOfflineMark")
    static let menuBarChatGPT = load("FigmaChatGPTMark")
    static let menuBarClaude = load("FigmaClaudeMark")
    static let menuBarChatGPTOffline = load("FigmaChatGPTOffline")
    static let menuBarClaudeOffline = load("FigmaClaudeOffline")

    static func image(for provider: ProviderKind) -> NSImage? {
        provider == .chatGPT ? chatGPT : claude
    }

    private static func load(_ name: String) -> NSImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "svg"),
              let image = NSImage(contentsOf: url) else {
            Diagnostics.log("Logo 資源載入失敗：\(name)")
            return nil
        }
        image.isTemplate = false
        Diagnostics.log("Logo 資源載入成功：\(name)")
        return image
    }
}

struct UsageMenuBarLabel: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        Image(nsImage: MenuBarArtwork.render(
            chatGPT: viewModel.settings.showCodex ? viewModel.codexSnapshot?.primary.remainingPercent : nil,
            showChatGPT: viewModel.settings.showCodex,
            claude: viewModel.settings.showClaude ? viewModel.claudeSnapshot?.primary.remainingPercent : nil,
            showClaude: viewModel.settings.showClaude,
            isOffline: viewModel.isOffline,
            compact: viewModel.settings.compactMenuBar
        ))
        .renderingMode(.original)
    }
}

struct UsageMenuView: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 14) {
                if viewModel.settings.showCodex {
                    ProviderSection(name: "ChatGPT", provider: .chatGPT, state: viewModel.codexState,
                                    isRefreshing: viewModel.isRefreshingCodex, now: context.date,
                                    staleCheck: viewModel.isStale)
                }
                if viewModel.settings.showCodex && viewModel.settings.showClaude { StyledDivider() }
                if viewModel.settings.showClaude {
                    ProviderSection(name: "Claude", provider: .claude, state: viewModel.claudeState,
                                    isRefreshing: viewModel.isRefreshingClaude, now: context.date,
                                    staleCheck: viewModel.isStale,
                                    disconnectAction: viewModel.claudeSession.isConnected ? {
                                        Task { await viewModel.disconnectClaude() }
                                    } : nil) {
                        Diagnostics.log("「連結 Claude」按鈕 action 已觸發")
                        viewModel.claudeSession.loadUsagePageIfNeeded()
                        ClaudeLoginWindowController.present(session: viewModel.claudeSession) {
                            Task { await viewModel.refreshClaude() }
                        }
                    }
                }
                StyledDivider()
                SettingsSection(settings: viewModel.settings)
                if viewModel.isOffline {
                    StatusBanner(title: "目前離線，已保留上次成功資料", symbol: "wifi.slash",
                                 color: UsageTheme.warning)
                }
                StyledDivider()
                FooterActions(viewModel: viewModel)
            }
            .padding(16)
            .frame(width: 330, alignment: .leading)
            .background(UsageTheme.surface)
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(UsageTheme.border, lineWidth: 1) }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color(hex: 0x111318).opacity(0.55), radius: 7.5, x: 0, y: 12)
        }
        .fixedSize(horizontal: true, vertical: false)
        .preferredColorScheme(.dark)
    }
}

enum ProviderKind {
    case chatGPT, claude
}

private struct ProviderSection: View {
    let name: String
    let provider: ProviderKind
    let state: UsageViewModel.State
    let isRefreshing: Bool
    let now: Date
    let staleCheck: (UsageSnapshot, Date) -> Bool
    var disconnectAction: (() -> Void)?
    var connectAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ProviderMark(provider: provider)
                Text(name).font(UsageFont.bold(14)).foregroundStyle(UsageTheme.primaryText)
                if let planName = displayPlanName {
                    Text(planName)
                        .font(UsageFont.bold(11)).foregroundStyle(UsageTheme.secondaryText)
                        .padding(5)
                        .background(UsageTheme.secondaryText.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Spacer(minLength: 8)
                if isRefreshing { ProgressView().controlSize(.small).tint(UsageTheme.blue) }
            }
            .frame(height: 24)

            if let snapshot {
                UsageWindowRow(window: snapshot.primary, now: now)
                UsageWindowRow(window: snapshot.secondary, now: now)
                Text("最後同步：\(LastSyncFormatter.string(fetchedAt: snapshot.fetchedAt, now: now))")
                    .font(UsageFont.regular(11)).foregroundStyle(UsageTheme.secondaryText)
                if staleCheck(snapshot, now) {
                    Label("資料已過期", systemImage: "clock.badge.exclamationmark")
                        .font(UsageFont.regular(11)).foregroundStyle(UsageTheme.warning)
                }
            } else if case .loading = state {
                Text("正在讀取用量…").font(UsageFont.regular(11)).foregroundStyle(UsageTheme.secondaryText)
            }

            if case .failed(let message, _) = state {
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(message).lineLimit(2)
                    Spacer(minLength: 6)
                    if let connectAction { CompactButton("連結", action: connectAction) }
                }
                .font(UsageFont.regular(11)).foregroundStyle(UsageTheme.orange)
            }
            if let disconnectAction {
                Button("斷開連結", role: .destructive, action: disconnectAction)
                    .font(UsageFont.regular(11))
                    .foregroundStyle(Color.white)
                    .underline()
                    .buttonStyle(.plain)
            }
        }
        .frame(width: 296, alignment: .leading)
    }

    private var snapshot: UsageSnapshot? {
        switch state {
        case .loading: nil
        case .loaded(let snapshot): snapshot
        case .failed(_, let cached): cached
        }
    }

    private var displayPlanName: String? {
        guard let planName = snapshot?.planName else { return nil }
        if provider == .claude && planName == "default_claude_ai" { return "PRO" }
        return planName.uppercased()
    }
}

private struct ProviderMark: View {
    let provider: ProviderKind
    var size: CGFloat = 20
    var body: some View {
        Group {
            if let logo = UsageLogos.image(for: provider) {
                Image(nsImage: logo)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(UsageTheme.warning)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct SettingsSection: View {
    @ObservedObject var settings: UsageSettings
    @State private var isExpanded = false
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 7) {
                    Text(isExpanded ? "▾" : "▸")
                        .font(UsageFont.regular(11)).foregroundStyle(UsageTheme.secondaryText)
                    Text("顯示與更新").font(UsageFont.bold(12))
                        .foregroundStyle(UsageTheme.primaryText)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).frame(height: 22, alignment: .top)

            if isExpanded {
                VStack(spacing: 8) {
                    StyledToggle("ChatGPT", isOn: $settings.showCodex, disabled: !settings.showClaude)
                    StyledToggle("Claude", isOn: $settings.showClaude, disabled: !settings.showCodex)
                    StyledToggle("狀態欄只顯示logo", isOn: $settings.compactMenuBar, disabled: false)
                    StyledToggle("用量低於50%提醒", isOn: $settings.lowUsageAlerts, disabled: false)
                    HStack {
                        Text("同步頻率").font(UsageFont.regular(12)).foregroundStyle(UsageTheme.primaryText)
                        Spacer()
                        Menu {
                            Button("60 秒") { settings.refreshInterval = 60 }
                            Button("5 分") { settings.refreshInterval = 300 }
                            Button("10 分") { settings.refreshInterval = 600 }
                            Button("30 分") { settings.refreshInterval = 1800 }
                        } label: {
                            Text(refreshLabel)
                                .font(UsageFont.bold(11))
                                .foregroundStyle(UsageTheme.secondaryText)
                                .padding(5)
                                .background(UsageTheme.secondaryText.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                    }.frame(width: 296, height: 24)
                    StyledToggle("開機時自動啟動", isOn: $launchAtLogin,
                                 disabled: !LaunchAtLogin.isAvailable)
                        .onChange(of: launchAtLogin) { _, enabled in
                            do { try LaunchAtLogin.setEnabled(enabled); launchError = nil }
                            catch { launchAtLogin = LaunchAtLogin.isEnabled; launchError = error.localizedDescription }
                        }
                    if !LaunchAtLogin.isAvailable {
                        Text("安裝 .app 後可啟用開機啟動")
                            .font(UsageFont.regular(10)).foregroundStyle(UsageTheme.secondaryText)
                    }
                    if let launchError {
                        Text(launchError).font(UsageFont.regular(10)).foregroundStyle(UsageTheme.warning)
                    }
                }
            }
        }
        .frame(width: 296, alignment: .topLeading)
    }

    private var refreshLabel: String {
        switch settings.refreshInterval {
        case 60: "60 秒"
        case 300: "5 分"
        case 600: "10 分"
        default: "30 分"
        }
    }
}

private struct StyledToggle: View {
    let title: String
    @Binding var isOn: Bool
    let disabled: Bool
    init(_ title: String, isOn: Binding<Bool>, disabled: Bool) {
        self.title = title; _isOn = isOn; self.disabled = disabled
    }
    var body: some View {
        Toggle(title, isOn: $isOn)
            .toggleStyle(UsageSwitchStyle())
            .font(UsageFont.regular(12))
            .foregroundStyle(UsageTheme.primaryText.opacity(isOn ? 1 : 0.6))
            .disabled(disabled)
            .frame(width: 296, height: 24)
    }
}

private struct UsageSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack {
                configuration.label
                Spacer()
                Capsule()
                    .fill(configuration.isOn ? UsageTheme.blue : UsageTheme.hover)
                    .frame(width: 32, height: 18)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle().fill(Color.white).frame(width: 14, height: 14).padding(2)
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "開啟" : "關閉")
    }
}

private struct UsageWindowRow: View {
    let window: UsageWindow
    let now: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(displayTitle).font(UsageFont.bold(13)); Spacer()
                Text("剩餘 \(window.remainingPercent)%")
                    .font(UsageFont.bold(14).monospacedDigit())
            }.foregroundStyle(UsageTheme.primaryText)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(UsageTheme.hover)
                    RoundedRectangle(cornerRadius: 3).fill(progressColor)
                        .frame(width: proxy.size.width * CGFloat(window.remainingPercent) / 100)
                }
            }.frame(height: 6)
            HStack { Text("已使用 \(window.usedPercent)%"); Spacer(); Text(resetText) }
                .font(UsageFont.regular(11)).foregroundStyle(UsageTheme.secondaryText)
        }.frame(width: 296, height: 65, alignment: .leading)
    }
    private var progressColor: Color {
        window.remainingPercent < 40 ? UsageTheme.orange : UsageTheme.blue
    }
    private var displayTitle: String {
        switch window.title {
        case "目前區段" where window.durationMinutes == 300: "5 小時區段"
        case "本週總額度" where window.durationMinutes == 10_080: "7 天總額度"
        default: window.title
        }
    }
    private var resetText: String {
        guard let resetsAt = window.resetsAt else { return "尚未開始" }
        let seconds = max(0, Int(resetsAt.timeIntervalSince(now)))
        let countdown: String
        if seconds >= 86_400 { countdown = "\(seconds / 86_400)d \((seconds % 86_400) / 3_600)h" }
        else { countdown = "\(seconds / 3_600)h \((seconds % 3_600) / 60)m" }
        let formatter = DateFormatter()
        formatter.dateFormat = seconds >= 86_400 ? "M/d HH:mm" : "HH:mm"
        return "\(formatter.string(from: resetsAt))（\(countdown)）"
    }
}

private struct FooterActions: View {
    @ObservedObject var viewModel: UsageViewModel
    @State private var updateUnavailable = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                CompactButton("整理用量", symbol: "arrow.clockwise") {
                    Task { await viewModel.refreshAll() }
                }
                .disabled(viewModel.isRefreshingCodex || viewModel.isRefreshingClaude)
                CompactButton(symbol: "doc.on.doc") { Diagnostics.copyToPasteboard() }
                    .help("複製診斷紀錄")
                CompactButton("檢查更新", symbol: "arrow.clockwise") {
                    updateUnavailable = !UpdateService.shared.checkForUpdates()
                }
                Spacer(minLength: 0)
                CompactButton("結束") { viewModel.quit() }
            }
            .frame(width: 296, height: 32)
            if updateUnavailable {
                Text("尚未設定更新來源，請先設定發布網址與簽章金鑰。")
                    .font(UsageFont.regular(10))
                    .foregroundStyle(UsageTheme.warning)
            }
        }
    }
}

private struct CompactButton: View {
    let title: String?; let symbol: String?; let action: () -> Void
    init(_ title: String, symbol: String? = nil, action: @escaping () -> Void) { self.title = title; self.symbol = symbol; self.action = action }
    init(symbol: String, action: @escaping () -> Void) { title = nil; self.symbol = symbol; self.action = action }
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) { if let symbol { Image(systemName: symbol) }; if let title { Text(title) } }
                .font(UsageFont.bold(12)).foregroundStyle(UsageTheme.primaryText)
                .padding(.horizontal, 8).frame(height: 32).background(UsageTheme.raised)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }.buttonStyle(.plain)
    }
}

private struct StatusBanner: View {
    let title: String; let symbol: String; let color: Color
    var body: some View {
        Label(title, systemImage: symbol).font(.system(size: 11)).foregroundStyle(color)
            .padding(8).background(color.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

private struct StyledDivider: View {
    var body: some View { Rectangle().fill(UsageTheme.border).frame(width: 296, height: 1) }
}

private extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
