import IOKit.ps

struct BatteryState: Equatable {
    var onBattery: Bool
    /// Charge from 0 to 100; `nil` on Macs without a battery.
    var percent: Int?

    static var current: BatteryState {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return BatteryState(onBattery: false) }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            let current = description[kIOPSCurrentCapacityKey] as? Int
            let max = description[kIOPSMaxCapacityKey] as? Int
            return BatteryState(
                onBattery: description[kIOPSPowerSourceStateKey] as? String == kIOPSBatteryPowerValue,
                percent: current.flatMap { current in max.flatMap { $0 > 0 ? current * 100 / $0 : nil } })
        }
        return BatteryState(onBattery: false)
    }
}

/// Lets closing the lid sleep the Mac again when the battery runs low,
/// so a closed MacBook left in a bag can't run itself flat.
enum LidSleepPolicy {
    static let minimumBattery = 20

    static func staysAwake(_ battery: BatteryState) -> Bool {
        guard battery.onBattery, let percent = battery.percent else { return true }
        return percent > minimumBattery
    }
}
