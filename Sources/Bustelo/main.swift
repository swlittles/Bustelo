import AppKit

if CommandLine.arguments.contains("--version") {
    print(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown")
    exit(0)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences.shared
    private var controller: SessionController!
    private var statusMenu: StatusMenu!

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let bundleID = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1 {
            NSApp.terminate(nil)
            return
        }
        controller = SessionController(preferences: preferences)
        statusMenu = StatusMenu(controller: controller, preferences: preferences)
        if preferences.startOnLaunch { controller.start(duration: nil) }
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
