import AppKit
import Testing
@testable import AIUsageMenuBar

@MainActor struct MenuBarArtworkTests {
    @Test func statusItemKeepsMenuBarHeightAndChangesWithProviders() {
        let both = MenuBarArtwork.render(chatGPT: 71, showChatGPT: true, claude: 62, showClaude: true, isOffline: false)
        let one = MenuBarArtwork.render(chatGPT: 71, showChatGPT: true, claude: nil, showClaude: false, isOffline: false)

        #expect(both.size.height == 22)
        #expect(one.size.height == 22)
        #expect(both.size.width > one.size.width)
        #expect(both.size.width < 150)
        let compact = MenuBarArtwork.render(chatGPT: 71, showChatGPT: true, claude: 62, showClaude: true, isOffline: false, compact: true)
        #expect(compact.size.width < both.size.width)
        #expect(compact.size.width == 29)
        #expect(UsageLogos.menuBarAivue != nil)
        #expect(UsageLogos.menuBarOffline != nil)
        #expect(UsageLogos.menuBarChatGPT != nil)
        #expect(UsageLogos.menuBarClaude != nil)
        #expect(UsageLogos.chatGPT != nil)
        #expect(UsageLogos.claude != nil)
    }
}
