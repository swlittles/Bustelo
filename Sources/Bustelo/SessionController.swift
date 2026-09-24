import AppKit

/// Owns the running session: the power assertion, the expiry, and idle nudges.
final class SessionController {
    private(set) var session: Session?
    /// Outcome of the most recent check, shown in the menu.
    private(set) var lastDecision: NudgeDecision?
    var onChange: (() -> Void)?

    private let preferences: Preferences
    private let assertion = PowerAssertion()
    private var ticker: Timer?
    private var wakeObserver: NSObjectProtocol?

    var isActive: Bool { session != nil }

    init(preferences: Preferences) {
        self.preferences = preferences
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.tick() }
    }

    deinit {
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
    }

    /// Starts (or restarts) a session. `nil` keeps the Mac awake until stopped.
    func start(duration: TimeInterval?) {
        resume(Session(duration: duration))
    }

    /// Runs an existing session, e.g. one interrupted by an update relaunch.
    func resume(_ session: Session) {
        guard !session.hasEnded(at: Date()) else { return stop() }
        self.session = session
        assertion.acquire(reason: "Bustelo is keeping this Mac awake")
        ticker?.invalidate()
        // Checking every few seconds keeps idle time within a few seconds of the threshold.
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in self?.tick() }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
        tick()
        onChange?()
    }

    func stop() {
        guard isActive else { return }
        session = nil
        lastDecision = nil
        ticker?.invalidate()
        ticker = nil
        assertion.release()
        onChange?()
    }

    /// Re-evaluates immediately, e.g. after the user changes a setting.
    func refresh() { tick() }

    private func tick() {
        guard let session else { return }
        if session.hasEnded(at: Date()) { return stop() }
        guard preferences.simulateActivity else { lastDecision = nil; return }
        let decision = NudgePolicy(idleThreshold: preferences.nudgeAfterSeconds).decide(SystemState.snapshot())
        if decision == .nudge { ActivityNudger.nudge() }
        lastDecision = decision
    }
}
