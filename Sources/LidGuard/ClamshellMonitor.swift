import Foundation
import IOKit

enum LidState: String {
    case open
    case closed
    case unknown
}

enum ClamshellMonitor {
    static func current() -> LidState {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOPMrootDomain")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return .unknown
        }
        defer { IOObjectRelease(iterator) }

        let entry = IOIteratorNext(iterator)
        guard entry != 0 else { return .unknown }
        defer { IOObjectRelease(entry) }

        guard let raw = IORegistryEntryCreateCFProperty(entry, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? Bool
        else { return .unknown }

        return raw ? .closed : .open
    }
}
