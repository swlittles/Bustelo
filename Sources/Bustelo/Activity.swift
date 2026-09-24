import AppKit
import CoreGraphics

enum SystemState {
    private static let anyInput = CGEventType(rawValue: ~0)!

    /// Seconds since the last input event of any kind, as apps checking for idleness see it.
    static var idleSeconds: TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    static func snapshot() -> SystemSnapshot {
        let session = CGSessionCopyCurrentDictionary() as? [String: Any] ?? [:]
        return SystemSnapshot(
            idleSeconds: idleSeconds,
            canPostEvents: ActivityNudger.hasPermission,
            onConsole: session[kCGSessionOnConsoleKey as String] as? Bool ?? false,
            screenLocked: session["CGSSessionScreenIsLocked"] as? Bool ?? false,
            displayAsleep: CGDisplayIsAsleep(CGMainDisplayID()) != 0,
            screenSaverRunning: NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.ScreenSaver.Engine" },
            mouseButtonDown: [CGMouseButton.left, .right, .center].contains {
                CGEventSource.buttonState(.combinedSessionState, button: $0)
            })
    }
}

/// Resets the system idle timer without touching anything on screen.
///
/// The event is a modifier-state change whose modifiers equal the ones already
/// held (normally none), so no key is pressed, no text is typed, and the pointer
/// never moves or clicks. The window server still counts it as input, which
/// resets the system idle time.
enum ActivityNudger {
    static var hasPermission: Bool { CGPreflightPostEventAccess() }

    /// Shows the system prompt once and adds Bustelo to the Accessibility list.
    static func requestPermission() {
        if !CGRequestPostEventAccess(),
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @discardableResult
    static func nudge() -> Bool {
        guard let event = CGEvent(source: CGEventSource(stateID: .hidSystemState)) else { return false }
        event.type = .flagsChanged
        event.flags = CGEventSource.flagsState(.combinedSessionState)
        event.post(tap: .cghidEventTap)
        return true
    }
}
