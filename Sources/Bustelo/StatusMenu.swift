import AppKit

final class StatusMenu: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let controller: SessionController
    private let preferences: Preferences
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let activityLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var liveTimer: Timer?

    init(controller: SessionController, preferences: Preferences) {
        self.controller = controller
        self.preferences = preferences
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu
        controller.onChange = { [weak self] in self?.refreshIcon() }
        refreshIcon()
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        refreshLines()
        statusLine.isEnabled = false
        activityLine.isEnabled = false
        menu.addItem(statusLine)
        if !activityLine.title.isEmpty { menu.addItem(activityLine) }
        if preferences.simulateActivity && !ActivityNudger.hasPermission {
            menu.addItem(action("Allow Accessibility Access…", #selector(requestPermission)))
        }
        menu.addItem(.separator())

        menu.addItem(controller.isActive
            ? action("Turn Off", #selector(turnOff))
            : action("Turn On", #selector(turnOn)))
        let durations = NSMenu()
        for (index, preset) in DurationPreset.all.enumerated() {
            let entry = action(preset.title, #selector(turnOnForPreset(_:)))
            entry.tag = index
            durations.addItem(entry)
        }
        let durationItem = NSMenuItem(title: controller.isActive ? "Keep Awake For" : "Turn On For", action: nil, keyEquivalent: "")
        durationItem.submenu = durations
        menu.addItem(durationItem)
        menu.addItem(.separator())

        menu.addItem(toggle("Keep Teams & Slack Active", preferences.simulateActivity, #selector(toggleSimulateActivity)))
        menu.addItem(toggle("Turn On When Bustelo Opens", preferences.startOnLaunch, #selector(toggleStartOnLaunch)))
        menu.addItem(toggle("Open at Login", preferences.openAtLogin, #selector(toggleOpenAtLogin)))
        menu.addItem(.separator())

        menu.addItem(action("About Bustelo", #selector(showAbout)))
        let quit = NSMenuItem(title: "Quit Bustelo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    func menuWillOpen(_ menu: NSMenu) {
        // Keep the countdown current while the menu stays open.
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.refreshLines() }
        RunLoop.main.add(timer, forMode: .common)
        liveTimer = timer
    }

    func menuDidClose(_ menu: NSMenu) {
        liveTimer?.invalidate()
        liveTimer = nil
    }

    private func action(_ title: String, _ selector: Selector) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        entry.target = self
        return entry
    }

    private func toggle(_ title: String, _ isOn: Bool, _ selector: Selector) -> NSMenuItem {
        let entry = action(title, selector)
        entry.state = isOn ? .on : .off
        return entry
    }

    private func refreshLines() {
        statusLine.title = statusText()
        activityLine.title = activityText()
    }

    private func statusText() -> String {
        guard let session = controller.session else { return "Off — your Mac sleeps normally" }
        guard let endsAt = session.endsAt, let remaining = session.remaining(at: Date()) else {
            return "Awake until you turn it off"
        }
        let time = endsAt.formatted(date: .omitted, time: .shortened)
        return "Awake until \(time) · \(RemainingFormat.short(remaining)) left"
    }

    private func activityText() -> String {
        guard controller.isActive, preferences.simulateActivity else { return "" }
        switch controller.lastDecision {
        case .skip(.noPermission): return "Needs Accessibility access to keep you Available"
        case .skip(.screenLocked): return "Status paused while the screen is locked"
        case .skip(.displayAsleep): return "Status paused while the display sleeps"
        case .skip(.screenSaver): return "Status paused during the screen saver"
        case .skip(.notOnConsole): return "Status paused while another user is active"
        default: return "Keeping Teams & Slack Available"
        }
    }

    private func refreshIcon() {
        let active = controller.isActive
        let image = NSImage(systemSymbolName: active ? "cup.and.saucer.fill" : "cup.and.saucer",
                            accessibilityDescription: active ? "Bustelo: awake" : "Bustelo: off")
        image?.isTemplate = true
        item.button?.image = image
        item.button?.toolTip = active ? "Bustelo is keeping your Mac awake" : "Bustelo is off"
    }

    // MARK: Actions

    @objc private func turnOn() { controller.start(duration: nil) }

    @objc private func turnOff() { controller.stop() }

    @objc private func turnOnForPreset(_ sender: NSMenuItem) {
        controller.start(duration: DurationPreset.all[sender.tag].seconds)
    }

    @objc private func toggleSimulateActivity() {
        preferences.simulateActivity.toggle()
        if preferences.simulateActivity && !ActivityNudger.hasPermission { ActivityNudger.requestPermission() }
        controller.refresh()
    }

    @objc private func toggleStartOnLaunch() { preferences.startOnLaunch.toggle() }

    @objc private func toggleOpenAtLogin() {
        do {
            try preferences.setOpenAtLogin(!preferences.openAtLogin)
        } catch {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert(error: error)
            alert.messageText = "Bustelo couldn’t change Open at Login"
            alert.runModal()
        }
    }

    @objc private func requestPermission() { ActivityNudger.requestPermission() }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSMutableAttributedString(string: "Keeps your Mac awake and your status Available.\n", attributes: [.font: NSFont.systemFont(ofSize: 11)])
        credits.append(NSAttributedString(string: "github.com/swlittles/Bustelo", attributes: [
            .font: NSFont.systemFont(ofSize: 11), .link: URL(string: "https://github.com/swlittles/Bustelo")!]))
        credits.setAlignment(.center, range: NSRange(location: 0, length: credits.length))
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
}
