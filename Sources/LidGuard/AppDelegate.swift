import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItemController = StatusItemController()
    private let core = LidGuardCore.shared
    private let settings = Settings.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        log(.info, "app: launching version \(Bundle.main.shortVersion)")
        statusItemController.install()
        core.start()
        if !settings.hasSeenWelcome {
            showWelcome()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        core.stop()
    }

    private func showWelcome() {
        settings.hasSeenWelcome = true

        let alert = NSAlert()
        alert.messageText = "LidGuard is running in your menu bar"
        alert.informativeText = """
        When you close the lid on battery, LidGuard turns Wi-Fi and Bluetooth off \
        so the machine can reach deep sleep. Opening the lid puts them back exactly \
        as they were. On AC power nothing changes.

        Recommended: let LidGuard start automatically at login, so it is protecting \
        the battery even after a restart. You can change this any time from the menu \
        bar icon.
        """
        alert.addButton(withTitle: "Launch at Login (recommended)")
        alert.addButton(withTitle: "Not Now")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            settings.setLaunchAtLogin(true)
        } else {
            log(.info, "welcome: user declined launch at login")
        }
        core.publishStatus()
    }
}

extension Bundle {
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}
