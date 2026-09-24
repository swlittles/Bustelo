import AppKit
import Sparkle

/// Sparkle updates for release builds. Development builds never start or contact the feed.
final class UpdateService: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    static let isEnabled = !(Bundle.main.bundleIdentifier ?? "").hasSuffix(".dev")
        && Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil

    /// Set when a scheduled check finds an update; shown in the menu instead of a window.
    private(set) var availableVersion: String?
    var onAvailabilityChange: (() -> Void)?
    /// Called just before Sparkle quits Bustelo to install an update.
    var onWillRelaunch: (() -> Void)?
    private var controller: SPUStandardUpdaterController?

    func start() {
        guard Self.isEnabled, controller == nil else { return }
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: self)
    }

    var canCheck: Bool { controller?.updater.canCheckForUpdates ?? false }

    var automaticChecks: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    var menuTitle: String { availableVersion.map { "Update to Bustelo \($0)…" } ?? "Check for Updates…" }

    func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        controller?.checkForUpdates(nil)
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) { onWillRelaunch?() }

    // A menu-bar app shouldn't pop windows over your work; scheduled finds wait in the menu.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        false
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        availableVersion = update.displayVersionString
        onAvailabilityChange?()
    }

    func standardUserDriverWillFinishUpdateSession() {
        availableVersion = nil
        onAvailabilityChange?()
    }
}
