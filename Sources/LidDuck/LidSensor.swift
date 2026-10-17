import Foundation
import IOKit.hid

final class LidSensor {
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private var nextProbe = 0.0
    private(set) var detail = "Looking for lid sensor"
    func reset() {
        if let device { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }
        if let manager { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }
        device = nil; manager = nil
    }
    deinit { reset() }
    func read(now: Double) -> Double? {
        if device == nil {
            guard now >= nextProbe else { return nil }
            nextProbe = now + 3
            reset()
            let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
            self.manager = manager
            let match: [String: Any] = [kIOHIDVendorIDKey: 0x05AC, kIOHIDProductIDKey: 0x8104, kIOHIDDeviceUsagePageKey: 0x20, kIOHIDDeviceUsageKey: 0x8A]
            IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
            let result = IOHIDManagerOpen(manager, 0)
            guard result == kIOReturnSuccess else { detail = "Sensor access failed (\(result))"; return nil }
            guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>, let found = devices.first else {
                detail = "No compatible lid-angle sensor found"; return nil
            }
            let opened = IOHIDDeviceOpen(found, 0)
            guard opened == kIOReturnSuccess else { detail = "Sensor open failed (\(opened))"; return nil }
            device = found
        }
        guard let device else { return nil }
        var bytes = [UInt8](repeating: 0, count: 8)
        var length = bytes.count
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &bytes, &length)
        guard result == kIOReturnSuccess, length >= 3, bytes[0] == 1 else {
            detail = "Sensor read failed (\(result))"; reset(); return nil
        }
        let angle = Int(bytes[1]) | (Int(bytes[2]) << 8)
        guard (0...180).contains(angle) else { detail = "Invalid sensor report"; reset(); return nil }
        detail = "Lid sensor connected"
        return Double(angle)
    }
}
