import Foundation
import IOKit

enum IdleMonitor {
    static func secondsSinceLastInput() -> Double {
        var iterator: io_iterator_t = 0
        let match = IOServiceMatching("IOHIDSystem")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator) == KERN_SUCCESS else {
            return 0
        }
        defer { IOObjectRelease(iterator) }

        let entry = IOIteratorNext(iterator)
        guard entry != 0 else { return 0 }
        defer { IOObjectRelease(entry) }

        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = properties?.takeRetainedValue() as? [String: Any],
              let idleNanos = dict["HIDIdleTime"] as? UInt64 else {
            return 0
        }
        return Double(idleNanos) / 1_000_000_000.0
    }
}
