import AppKit

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let core = LidGuardCore.shared
    private let settings = Settings.shared

    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let enabledItem = NSMenuItem(title: "Active", action: #selector(toggleEnabled), keyEquivalent: "")
    private let bluetoothItem = NSMenuItem(title: "Cut Bluetooth too", action: #selector(toggleBluetooth), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")

    func install() {
        let menu = NSMenu()
        menu.delegate = self

        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())

        for item in [enabledItem, bluetoothItem, loginItem] {
            item.target = self
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let logItem = NSMenuItem(title: "Open Log", action: #selector(openLog), keyEquivalent: "l")
        logItem.target = self
        menu.addItem(logItem)

        let aboutItem = NSMenuItem(title: "About LidGuard", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit LidGuard", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        core.onStatusChange = { [weak self] status in
            DispatchQueue.main.async { self?.render(status) }
        }
        render(core.status)
    }

    func menuWillOpen(_ menu: NSMenu) {
        core.refreshRadioState()
        render(core.status)
    }

    private func render(_ status: GuardStatus) {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: status.symbolName, accessibilityDescription: "LidGuard")
            button.image?.isTemplate = true
            button.toolTip = "LidGuard: \(status.menuText)"
        }
        let power = PowerMonitor.current()
        statusLine.title = "\(status.menuText) (\(power.percent)%)"
        enabledItem.state = settings.isEnabled ? .on : .off
        bluetoothItem.state = settings.cutsBluetooth ? .on : .off
        loginItem.state = settings.launchesAtLogin ? .on : .off
    }

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
        log(.info, "settings: active set to \(settings.isEnabled)")
        core.publishStatus()
    }

    @objc private func toggleBluetooth() {
        settings.cutsBluetooth.toggle()
        log(.info, "settings: cut Bluetooth set to \(settings.cutsBluetooth)")
        core.publishStatus()
    }

    @objc private func toggleLaunchAtLogin() {
        settings.setLaunchAtLogin(!settings.launchesAtLogin)
        core.publishStatus()
    }

    @objc private func openLog() {
        NSWorkspace.shared.open(Log.fileURL)
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "LidGuard"
        alert.informativeText = """
        Cuts Wi-Fi and Bluetooth when the lid closes on battery, and restores \
        them when you open it again.

        Built to stop Apple Silicon dark-wake battery drain, where the Wi-Fi chip \
        wakes the SoC on every inbound IP packet and no pmset setting suppresses it.

        Log: ~/Library/Logs/LidGuard.log
        """
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "View on GitHub")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn {
            NSWorkspace.shared.open(URL(string: "https://github.com/adipascu/LidGuard")!)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
