import Foundation
import ServiceManagement

final class Preferences {
    static let shared = Preferences()

    private enum Key {
        static let simulateActivity = "SimulateActivity"
        static let startOnLaunch = "StartOnLaunch"
        static let nudgeAfterSeconds = "NudgeAfterSeconds"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Key.simulateActivity: true, Key.startOnLaunch: false, Key.nudgeAfterSeconds: 60])
    }

    /// Keep Teams and Slack from marking you Away while a session runs.
    var simulateActivity: Bool {
        get { defaults.bool(forKey: Key.simulateActivity) }
        set { defaults.set(newValue, forKey: Key.simulateActivity) }
    }

    var startOnLaunch: Bool {
        get { defaults.bool(forKey: Key.startOnLaunch) }
        set { defaults.set(newValue, forKey: Key.startOnLaunch) }
    }

    /// Idle time before a nudge. Teams goes Away after 5 minutes and Slack after 10,
    /// so the default leaves plenty of margin. Hidden setting for testing:
    /// `defaults write io.github.swlittles.Bustelo NudgeAfterSeconds 30`.
    var nudgeAfterSeconds: TimeInterval {
        min(240, max(5, defaults.double(forKey: Key.nudgeAfterSeconds)))
    }

    var openAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    func setOpenAtLogin(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
            if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
