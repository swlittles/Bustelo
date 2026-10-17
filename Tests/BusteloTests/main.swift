import Foundation

var failures = 0
func expect(_ condition: Bool, _ message: String, line: Int = #line) {
    if !condition { failures += 1; print("FAIL line \(line): \(message)") }
}

// Session
let start = Date(timeIntervalSince1970: 1_000_000)
let open = Session(startedAt: start, duration: nil)
expect(open.endsAt == nil, "open-ended session has no end")
expect(open.duration == nil, "open-ended session remembers no duration")
expect(!open.hasEnded(at: start.addingTimeInterval(365 * 86_400)), "open-ended session never ends")
expect(open.remaining(at: start) == nil, "open-ended session has no remaining time")

let hour = Session(startedAt: start, duration: 3600)
expect(hour.duration == 3600, "session remembers the picked duration")
expect(hour.endsAt == start.addingTimeInterval(3600), "end derives from start and duration")
expect(hour.remaining(at: start.addingTimeInterval(600)) == 3000, "remaining counts down")
expect(!hour.hasEnded(at: start.addingTimeInterval(3599)), "not ended just before the end")
expect(hour.hasEnded(at: start.addingTimeInterval(3600)), "ended exactly at the end")
expect(hour.remaining(at: start.addingTimeInterval(9999)) == 0, "remaining never goes negative")

// Remaining time formatting
expect(RemainingFormat.short(59 * 60 + 1) == "1h", "rounds up into the next hour")
expect(RemainingFormat.short(65 * 60) == "1h 5m", "hours and minutes")
expect(RemainingFormat.short(2 * 3600) == "2h", "whole hours omit minutes")
expect(RemainingFormat.short(45 * 60) == "45m", "minutes only")
expect(RemainingFormat.short(10) == "1m", "final minute never shows 0m")
expect(RemainingFormat.short(0) == "1m", "zero still reads 1m")

// Presets
expect(DurationPreset.all.map(\.seconds) == DurationPreset.all.map(\.seconds).sorted(), "presets ascend")
expect(DurationPreset.all.first?.seconds == 15 * 60 && DurationPreset.all.last?.seconds == 8 * 3600, "preset range")

expect(DurationPreset.index(of: nil) == nil, "indefinite matches no timed preset")
expect(DurationPreset.index(of: 3600) == 2, "a picked preset is found for its checkmark")
expect(DurationPreset.index(of: 3599) == nil, "other lengths match nothing")

// Nudge policy
let policy = NudgePolicy(idleThreshold: 60)
let idle = SystemSnapshot(idleSeconds: 61)
expect(policy.decide(idle) == .nudge, "nudges once idle past the threshold")
expect(policy.decide(SystemSnapshot(idleSeconds: 60)) == .nudge, "threshold is inclusive")
expect(policy.decide(SystemSnapshot(idleSeconds: 59)) == .skip(.userActive), "leaves active users alone")

var variant = idle; variant.canPostEvents = false
expect(policy.decide(variant) == .skip(.noPermission), "needs permission")
variant = idle; variant.onConsole = false
expect(policy.decide(variant) == .skip(.notOnConsole), "skips when another user has the console")
variant = idle; variant.screenLocked = true
expect(policy.decide(variant) == .skip(.screenLocked), "respects a locked screen")
variant = idle; variant.displayAsleep = true
expect(policy.decide(variant) == .skip(.displayAsleep), "never wakes a sleeping display")
variant = idle; variant.screenSaverRunning = true
expect(policy.decide(variant) == .skip(.screenSaver), "never dismisses the screen saver")
variant = idle; variant.mouseButtonDown = true
expect(policy.decide(variant) == .skip(.mouseButtonDown), "never interrupts a click or drag")

variant = SystemSnapshot(idleSeconds: 5, canPostEvents: false, screenLocked: true)
expect(policy.decide(variant) == .skip(.noPermission), "permission is reported first")

// Lid helper
expect(LidHelper.label(appBundleID: "io.github.swlittles.Bustelo") == "io.github.swlittles.Bustelo.LidHelper", "helper label follows the app")
expect(LidHelper.label(appBundleID: "a.dev") != LidHelper.label(appBundleID: "a"), "development builds get their own helper")
expect(LidHelper.clientRequirement(appBundleID: "a", teamID: "TEAM") ==
       "anchor apple generic and identifier \"a\" and certificate leaf[subject.OU] = \"TEAM\"", "signed builds pin the team")
expect(LidHelper.clientRequirement(appBundleID: "a", teamID: nil) == "identifier \"a\"", "ad-hoc builds check the identifier")
expect(LidHelper.clientRequirement(appBundleID: "a", teamID: "") == "identifier \"a\"", "an empty team counts as none")
let pmsetOn = "System-wide power settings:\n SleepDisabled\t\t1\nCurrently in use:\n standby              1\n"
let pmsetOff = "System-wide power settings:\nCurrently in use:\n standby              1\n sleep                1\n"
expect(LidHelper.sleepDisabled(pmsetOutput: pmsetOn), "reads SleepDisabled when set")
expect(!LidHelper.sleepDisabled(pmsetOutput: pmsetOff), "absent SleepDisabled means sleep is allowed")
expect(!LidHelper.sleepDisabled(pmsetOutput: " SleepDisabled\t\t0\n"), "SleepDisabled 0 means sleep is allowed")
// Low battery
expect(LidSleepPolicy.staysAwake(BatteryState(onBattery: false, percent: 5)), "plugged in stays awake at any charge")
expect(LidSleepPolicy.staysAwake(BatteryState(onBattery: true, percent: 21)), "stays awake above the cutoff")
expect(!LidSleepPolicy.staysAwake(BatteryState(onBattery: true, percent: 20)), "lid sleeps again at the cutoff")
expect(LidSleepPolicy.staysAwake(BatteryState(onBattery: false, percent: nil)), "Macs without a battery stay awake")
let reading = BatteryState.current
expect(reading.percent.map { (0...100).contains($0) } ?? true, "this Mac's charge reads as a percentage")

if failures > 0 { print("\(failures) failure(s)"); exit(1) }
print("All Bustelo tests passed")
