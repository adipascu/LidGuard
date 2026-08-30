import AppKit

enum GuardStatus {
    case disabled
    case armed
    case cut
    case idleOnAC

    var menuText: String {
        switch self {
        case .disabled: return "Paused"
        case .armed: return "Armed, will cut on lid close"
        case .cut: return "Radios cut, sleeping on battery"
        case .idleOnAC: return "Idle, on AC power"
        }
    }

    var symbolName: String {
        switch self {
        case .disabled: return "laptopcomputer.slash"
        case .armed: return "laptopcomputer"
        case .cut: return "wifi.slash"
        case .idleOnAC: return "laptopcomputer"
        }
    }
}

@MainActor
final class LidGuardCore {
    static let shared = LidGuardCore()

    private let radios = RadioController()
    private let settings = Settings.shared
    private var observers: [NSObjectProtocol] = []

    var onStatusChange: ((GuardStatus) -> Void)?

    private static let stateURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/LidGuard/saved-radio-state.json")

    private var savedState: RadioSnapshot? {
        get {
            guard let data = try? Data(contentsOf: Self.stateURL) else { return nil }
            return try? JSONDecoder().decode(RadioSnapshot.self, from: data)
        }
        set {
            let url = Self.stateURL
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let value = newValue, let data = try? JSONEncoder().encode(value) {
                try? data.write(to: url)
            } else {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    func start() {
        radios.warmUpBluetooth { [weak self] in
            DispatchQueue.main.async { self?.publishStatus() }
        }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleWillSleep()
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleDidWake()
        })

        let power = PowerMonitor.current()
        log(.info, "core: started \(power.description) lid=\(ClamshellMonitor.current().rawValue) \(radios.stateDescription)")
        recoverIfNeeded()
        publishStatus()
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
        restoreIfNeeded(reason: "app quitting", requireLidOpen: false)
        log(.info, "core: stopped, no longer managing radios")
    }

    var status: GuardStatus {
        if !settings.isEnabled { return .disabled }
        if savedState != nil { return .cut }
        return PowerMonitor.current().isOnBattery ? .armed : .idleOnAC
    }

    func refreshRadioState() {
        radios.refreshBluetooth()
    }

    func publishStatus() {
        onStatusChange?(status)
    }

    private func handleWillSleep() {
        let power = PowerMonitor.current()
        log(.info, "sleep: fired \(power.description) lid=\(ClamshellMonitor.current().rawValue) \(radios.stateDescription)")

        guard settings.isEnabled else {
            log(.info, "sleep: paused by user, radios untouched")
            return
        }
        guard power.isOnBattery else {
            log(.info, "sleep: on AC, radios untouched")
            return
        }

        if savedState == nil {
            let snapshot = radios.snapshot()
            savedState = snapshot
            log(.info, "sleep: saved \(snapshot.description) charge=\(snapshot.batteryPercent)%")
        } else {
            log(.info, "sleep: state already saved, keeping the original")
        }

        radios.setWiFi(false)
        if settings.cutsBluetooth {
            radios.setBluetooth(false)
        }
        log(.info, "sleep: cut radios, verified \(radios.stateDescription)")
        publishStatus()
    }

    private func handleDidWake() {
        guard savedState != nil else {
            log(.info, "wake: fired lid=\(ClamshellMonitor.current().rawValue), no saved state so nothing to restore")
            publishStatus()
            return
        }
        restoreIfNeeded(reason: "wake", requireLidOpen: true)
        publishStatus()
    }

    private func recoverIfNeeded() {
        guard savedState != nil else { return }
        log(.warn, "core: found saved state at launch, recovering from an unclean shutdown")
        restoreIfNeeded(reason: "launch recovery", requireLidOpen: false)
    }

    private func restoreIfNeeded(reason: String, requireLidOpen: Bool) {
        guard let saved = savedState else { return }

        if requireLidOpen, ClamshellMonitor.current() == .closed {
            log(.info, "wake: dark wake with lid closed, charge=\(PowerMonitor.current().percent)%, radios stay off")
            return
        }

        radios.setWiFi(saved.wifiOn)
        if let bluetooth = saved.bluetoothOn, settings.cutsBluetooth {
            radios.setBluetooth(bluetooth)
        }
        savedState = nil

        let now = PowerMonitor.current().percent
        let elapsed = Int(Date().timeIntervalSince(saved.takenAt))
        log(.info, "wake: \(reason), restored \(radios.stateDescription) wanted \(saved.description)")
        log(.info, "wake: asleep \(Self.duration(elapsed)) charge \(saved.batteryPercent)% -> \(now)% drain \(saved.batteryPercent - now)%")
    }

    private static func duration(_ seconds: Int) -> String {
        String(format: "%dh%02dm%02ds", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }
}
