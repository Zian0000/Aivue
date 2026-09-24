import SwiftUI
import CoreText

private enum AppFonts {
    static func register() {
        guard let url = AppResourceBundle.current.url(forResource: "InterVariable", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

@main
struct AIUsageMenuBarApp: App {
    @StateObject private var claudeSession: ClaudeSessionController
    @StateObject private var viewModel: UsageViewModel

    init() {
        AppFonts.register()
        _ = UpdateService.shared
        let claudeSession = ClaudeSessionController()
        _claudeSession = StateObject(wrappedValue: claudeSession)
        _viewModel = StateObject(
            wrappedValue: UsageViewModel(
                codexProvider: CodexUsageProvider(),
                claudeSession: claudeSession
            )
        )
    }

    var body: some Scene {
        MenuBarExtra {
            UsageMenuView(viewModel: viewModel)
        } label: {
            UsageMenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

    }
}
