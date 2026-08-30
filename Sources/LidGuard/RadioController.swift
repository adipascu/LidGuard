import Foundation
import CoreWLAN
import CBluetoothShim

struct RadioSnapshot: Codable {
    var wifiOn: Bool
    var bluetoothOn: Bool?
    var takenAt: Date
    var batteryPercent: Int

    var description: String {
        let bluetooth = bluetoothOn.map { $0 ? "on" : "off" } ?? "unavailable"
        return "wifi=\(wifiOn ? "on" : "off") bluetooth=\(bluetooth)"
    }
}

private final class BluetoothCache: @unchecked Sendable {
    private let lock = NSLock()
    private var state: Bool?
    private var warm = false

    var value: Bool? {
        lock.lock()
        defer { lock.unlock() }
        return state
    }

    var isWarm: Bool {
        lock.lock()
        defer { lock.unlock() }
        return warm
    }

    func update(_ newValue: Bool?, warm newWarm: Bool = true) {
        lock.lock()
        state = newValue
        warm = newWarm
        lock.unlock()
    }
}

final class RadioController {
    private let sleepPathTimeout: TimeInterval = 2.0
    private let bluetooth = BluetoothCache()

    var wifiInterfaceName: String? {
        CWWiFiClient.shared().interface()?.interfaceName
    }

    var wifiIsOn: Bool {
        CWWiFiClient.shared().interface()?.powerOn() ?? false
    }

    @discardableResult
    func setWiFi(_ on: Bool) -> Bool {
        guard let interface = CWWiFiClient.shared().interface() else {
            log(.error, "radio: no Wi-Fi interface available")
            return false
        }
        do {
            try interface.setPower(on)
            return true
        } catch {
            log(.error, "radio: failed to set Wi-Fi \(on ? "on" : "off"), \(error.localizedDescription)")
            return false
        }
    }

    var bluetoothIsOn: Bool? { bluetooth.value }

    var bluetoothIsWarm: Bool { bluetooth.isWarm }

    func warmUpBluetooth(completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .utility).async { [bluetooth] in
            let started = Date()
            let state = lgBluetoothPowerState() != 0
            let elapsed = Date().timeIntervalSince(started)
            bluetooth.update(state)
            log(.info, "radio: Bluetooth ready, state=\(state ? "on" : "off") after \(String(format: "%.2f", elapsed))s")
            completion?()
        }
    }

    func refreshBluetooth() {
        guard bluetooth.isWarm else { return }
        DispatchQueue.global(qos: .utility).async { [bluetooth] in
            bluetooth.update(lgBluetoothPowerState() != 0)
        }
    }

    @discardableResult
    func setBluetooth(_ on: Bool) -> Bool {
        guard bluetooth.isWarm else {
            log(.warn, "radio: Bluetooth not ready yet, skipping so sleep is never delayed")
            return false
        }

        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async { [bluetooth] in
            lgSetBluetoothPowerState(on ? 1 : 0)
            bluetooth.update(on)
            semaphore.signal()
        }

        if semaphore.wait(timeout: .now() + sleepPathTimeout) == .success {
            return true
        }
        log(.warn, "radio: Bluetooth set timed out after \(sleepPathTimeout)s, Wi-Fi was still handled")
        return false
    }

    func snapshot() -> RadioSnapshot {
        RadioSnapshot(
            wifiOn: wifiIsOn,
            bluetoothOn: bluetoothIsOn,
            takenAt: Date(),
            batteryPercent: PowerMonitor.current().percent
        )
    }

    var stateDescription: String {
        let bluetoothText = bluetoothIsOn.map { $0 ? "on" : "off" } ?? (bluetoothIsWarm ? "unavailable" : "starting")
        return "wifi=\(wifiIsOn ? "on" : "off") bluetooth=\(bluetoothText)"
    }
}
