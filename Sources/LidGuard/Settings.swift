import Foundation
import ServiceManagement

final class Settings: @unchecked Sendable {
    static let shared = Settings()

    private enum Key {
        static let enabled = "enabled"
        static let cutBluetooth = "cutBluetooth"
        static let hasSeenWelcome = "hasSeenWelcome"
    }

    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            Key.enabled: true,
            Key.cutBluetooth: true,
            Key.hasSeenWelcome: false,
        ])
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    var cutsBluetooth: Bool {
        get { defaults.bool(forKey: Key.cutBluetooth) }
        set { defaults.set(newValue, forKey: Key.cutBluetooth) }
    }

    var hasSeenWelcome: Bool {
        get { defaults.bool(forKey: Key.hasSeenWelcome) }
        set { defaults.set(newValue, forKey: Key.hasSeenWelcome) }
    }

    var launchesAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            log(.info, "settings: launch at login \(enabled ? "enabled" : "disabled")")
        } catch {
            log(.error, "settings: could not change launch at login, \(error.localizedDescription)")
        }
    }
}
