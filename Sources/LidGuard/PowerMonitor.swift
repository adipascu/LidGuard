import Foundation
import IOKit.ps

enum PowerSource: String {
    case battery = "Battery Power"
    case ac = "AC Power"
    case unknown = "Unknown"
}

struct PowerState {
    let source: PowerSource
    let percent: Int

    var isOnBattery: Bool { source == .battery }

    var description: String { "power='\(source.rawValue)' charge=\(percent)%" }
}

enum PowerMonitor {
    static func current() -> PowerState {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return PowerState(source: .unknown, percent: -1)
        }

        for item in list {
            guard let raw = IOPSGetPowerSourceDescription(snapshot, item)?.takeUnretainedValue(),
                  let info = raw as? [String: Any]
            else { continue }

            let stateString = info[kIOPSPowerSourceStateKey] as? String ?? ""
            let source = PowerSource(rawValue: stateString) ?? .unknown
            let percent = info[kIOPSCurrentCapacityKey] as? Int ?? -1
            return PowerState(source: source, percent: percent)
        }

        return PowerState(source: .unknown, percent: -1)
    }
}
