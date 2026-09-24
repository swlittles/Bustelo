import IOKit.pwr_mgt

/// Keeps the display on, which also keeps the Mac from idle sleeping.
/// Visible in `pmset -g assertions`; released automatically if Bustelo exits.
final class PowerAssertion {
    private var id = IOPMAssertionID(0)
    private(set) var isHeld = false

    @discardableResult
    func acquire(reason: String) -> Bool {
        guard !isHeld else { return true }
        isHeld = IOPMAssertionCreateWithName("PreventUserIdleDisplaySleep" as CFString,
                                             IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                             reason as CFString, &id) == kIOReturnSuccess
        return isHeld
    }

    func release() {
        guard isHeld else { return }
        IOPMAssertionRelease(id)
        isHeld = false
    }

    deinit { release() }
}
