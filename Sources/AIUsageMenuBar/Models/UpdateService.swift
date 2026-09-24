import Foundation
import Sparkle

@MainActor
final class UpdateService {
    static let shared = UpdateService()
    private let controller: SPUStandardUpdaterController?

    private init() {
        let info = Bundle.main.infoDictionary ?? [:]
        let feed = info["SUFeedURL"] as? String
        let key = info["SUPublicEDKey"] as? String
        guard let feed, URL(string: feed)?.scheme == "https", key?.isEmpty == false,
              Bundle.main.bundleURL.pathExtension == "app" else {
            controller = nil
            Diagnostics.log("自動更新尚未設定：需要 HTTPS appcast 與 Sparkle 公鑰")
            return
        }
        controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
        )
    }

    var isConfigured: Bool { controller != nil }

    @discardableResult
    func checkForUpdates() -> Bool {
        guard let controller else { return false }
        controller.checkForUpdates(nil)
        return true
    }
}
