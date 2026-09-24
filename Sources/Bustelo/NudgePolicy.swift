import Foundation

/// What the system looks like at the moment Bustelo considers a nudge.
struct SystemSnapshot: Equatable {
    var idleSeconds: TimeInterval
    var canPostEvents = true
    var onConsole = true
    var screenLocked = false
    var displayAsleep = false
    var screenSaverRunning = false
    var mouseButtonDown = false
}

enum NudgeDecision: Equatable {
    case nudge
    case skip(SkipReason)
}

enum SkipReason: Equatable {
    /// Real input happened recently; nothing to do.
    case userActive
    case noPermission
    /// Another user owns the console (fast user switching).
    case notOnConsole
    /// Respect a deliberate lock; a locked Mac should count as idle.
    case screenLocked
    /// The display was slept on purpose; input could wake it.
    case displayAsleep
    /// Input would dismiss a screen saver started on purpose.
    case screenSaver
    /// Never inject anything in the middle of a click or drag.
    case mouseButtonDown
}

/// Decides whether to reset the idle timer. Only acts once the user has been idle
/// for `idleThreshold`, so it never competes with real input.
struct NudgePolicy {
    var idleThreshold: TimeInterval

    func decide(_ system: SystemSnapshot) -> NudgeDecision {
        if !system.canPostEvents { return .skip(.noPermission) }
        if !system.onConsole { return .skip(.notOnConsole) }
        if system.screenLocked { return .skip(.screenLocked) }
        if system.displayAsleep { return .skip(.displayAsleep) }
        if system.screenSaverRunning { return .skip(.screenSaver) }
        if system.mouseButtonDown { return .skip(.mouseButtonDown) }
        if system.idleSeconds < idleThreshold { return .skip(.userActive) }
        return .nudge
    }
}
