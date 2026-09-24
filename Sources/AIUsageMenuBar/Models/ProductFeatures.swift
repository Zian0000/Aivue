import AppKit
import ServiceManagement
import UserNotifications

@MainActor
enum LaunchAtLogin {
    static var isAvailable: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    static var isEnabled: Bool {
        isAvailable && SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        guard isAvailable else {
            throw FeatureError.requiresAppBundle
        }
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

enum FeatureError: LocalizedError {
    case requiresAppBundle

    var errorDescription: String? {
        switch self {
        case .requiresAppBundle: "請先安裝正式 .app，才能設定開機啟動。"
        }
    }
}

@MainActor
final class LowUsageNotifier {
    static func shouldNotify(remainingPercent: Int) -> Bool { remainingPercent < 50 }

    private let defaults = UserDefaults.standard
    private let key = "lowUsageAlertedWindows"
    private var pending = Set<String>()

    func check(_ snapshot: UsageSnapshot, provider: String, enabled: Bool) async {
        guard enabled, Bundle.main.bundleURL.pathExtension == "app" else { return }
        for (kind, window) in [("目前區段", snapshot.primary), ("總額度", snapshot.secondary)] {
            let key = "\(provider):\(kind):\(window.resetsAt?.timeIntervalSince1970 ?? 0)"
            guard Self.shouldNotify(remainingPercent: window.remainingPercent) else { continue }
            var alerted = Set(defaults.stringArray(forKey: self.key) ?? [])
            guard !alerted.contains(key), pending.insert(key).inserted else { continue }
            defer { pending.remove(key) }
            let title = "\(provider) \(kind)剩餘 \(window.remainingPercent)%"
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound])
                guard granted else { return }
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = "用量即將達到上限，請查看狀態欄中的重置時間。"
                content.sound = .default
                let request = UNNotificationRequest(identifier: key, content: content, trigger: nil)
                try await UNUserNotificationCenter.current().add(request)
                alerted.insert(key)
                alerted = Set(alerted.filter { $0.hasPrefix("\(provider):\(kind):") == false || $0 == key })
                defaults.set(Array(alerted), forKey: self.key)
            } catch {
                Diagnostics.log("低用量提醒未能送出：\(error.localizedDescription)")
            }
        }
    }
}
