import AppKit
import ServiceManagement

let arguments = Set(CommandLine.arguments.dropFirst())

if arguments.contains("--help") {
    print("""
    LidGuard \(Bundle.main.shortVersion)

    Runs as a menu bar app with no arguments.

      --enable-login-item    register LidGuard to start at login, then exit
      --disable-login-item   unregister the login item, then exit
      --status               print the current login item status, then exit
      --help                 show this message
    """)
    exit(0)
}

if arguments.contains("--enable-login-item") || arguments.contains("--disable-login-item") {
    let enable = arguments.contains("--enable-login-item")
    Settings.shared.setLaunchAtLogin(enable)
    let isEnabled = SMAppService.mainApp.status == .enabled
    print("login item: \(isEnabled ? "enabled" : "not enabled")")
    exit(isEnabled == enable ? 0 : 1)
}

if arguments.contains("--status") {
    print("login item: \(SMAppService.mainApp.status == .enabled ? "enabled" : "not enabled")")
    print("active: \(Settings.shared.isEnabled)")
    print("cuts bluetooth: \(Settings.shared.cutsBluetooth)")
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
