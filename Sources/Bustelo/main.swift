import AppKit

if CommandLine.arguments.contains("--version") {
    print(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown")
    exit(0)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences.shared
    private let updates = UpdateService()
    private var controller: SessionController!
    private var statusMenu: StatusMenu!

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let bundleID = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1 {
            NSApp.terminate(nil)
            return
        }
        controller = SessionController(preferences: preferences)
        statusMenu = StatusMenu(controller: controller, preferences: preferences, updates: updates)
        updates.onWillRelaunch = { [weak self] in
            guard let self, let session = self.controller.session else { return }
            self.preferences.saveResumableSession(session)
        }
        updates.start()
        if let interrupted = preferences.takeResumableSession(), !interrupted.hasEnded(at: Date()) {
            // Continue a session that an update relaunch interrupted.
            controller.resume(interrupted)
        } else if preferences.startOnLaunch {
            controller.start(duration: nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
