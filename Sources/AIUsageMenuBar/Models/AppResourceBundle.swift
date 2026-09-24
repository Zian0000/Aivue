import Foundation

enum AppResourceBundle {
    static let current: Bundle = {
        if let resourceURL = Bundle.main.resourceURL,
           let appBundle = Bundle(url: resourceURL.appendingPathComponent("AIUsageMenuBar_AIUsageMenuBar.bundle")) {
            return appBundle
        }
        return Bundle.module
    }()
}
