import Foundation
import LidHelperInterface
import os
import Security

// Bustelo's lid helper. launchd runs it as root, and its one job is `pmset disablesleep`:
// on while at least one connected Bustelo asks for it, off as soon as none does.

private let log = Logger(subsystem: "io.github.swlittles.Bustelo", category: "LidHelper")

/// Turns system sleep off and back on, and only ever undoes its own change.
final class SleepSwitch {
    private let queue = DispatchQueue(label: "LidHelper.SleepSwitch")
    /// Exists while this helper has sleep disabled, so a crash or power loss is undone at the next launch.
    private let marker: URL
    private var holders = Set<ObjectIdentifier>()

    init(marker: URL) {
        self.marker = marker
        queue.sync {
            if ownsSetting {
                log.notice("Restoring sleep left disabled by an earlier run")
                _ = restore()
            }
        }
    }

    private var ownsSetting: Bool { FileManager.default.fileExists(atPath: marker.path) }

    /// Returns whether the request took effect.
    func set(_ holder: ObjectIdentifier, holding: Bool) -> Bool {
        queue.sync {
            if holding { holders.insert(holder) } else { holders.remove(holder) }
            return holders.isEmpty ? restore() : disable()
        }
    }

    func releaseAll() {
        queue.sync {
            holders.removeAll()
            _ = restore()
        }
    }

    private func disable() -> Bool {
        if ownsSetting { return true }
        // Already off, e.g. someone ran `pmset disablesleep 1` themselves: leave their setting alone.
        if Self.isSleepDisabled { return true }
        do {
            try FileManager.default.createDirectory(at: marker.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: marker)
        } catch {
            log.error("Couldn't write \(self.marker.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
        guard Self.pmset("-a", "disablesleep", "1") != nil else {
            try? FileManager.default.removeItem(at: marker)
            return false
        }
        log.notice("Lid sleep disabled")
        return true
    }

    private func restore() -> Bool {
        guard ownsSetting else { return true }
        guard Self.pmset("-a", "disablesleep", "0") != nil else { return false }
        try? FileManager.default.removeItem(at: marker)
        log.notice("Lid sleep restored")
        return true
    }

    private static var isSleepDisabled: Bool {
        pmset("-g").map(LidHelper.sleepDisabled(pmsetOutput:)) ?? false
    }

    /// Runs pmset and returns its output, or `nil` if it failed.
    private static func pmset(_ arguments: String...) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        do { try process.run() } catch {
            log.error("pmset didn't start: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            log.error("pmset \(arguments.joined(separator: " "), privacy: .public) exited \(process.terminationStatus)")
            return nil
        }
        return String(decoding: data, as: UTF8.self)
    }
}

/// One per connected Bustelo; its identity is the hold.
final class Client: NSObject, LidHelperProtocol {
    private let sleepSwitch: SleepSwitch

    init(sleepSwitch: SleepSwitch) { self.sleepSwitch = sleepSwitch }

    func setLidSleepDisabled(_ disabled: Bool, reply: @escaping (Bool) -> Void) {
        reply(sleepSwitch.set(ObjectIdentifier(self), holding: disabled))
    }
}

final class Listener: NSObject, NSXPCListenerDelegate {
    private let sleepSwitch: SleepSwitch
    private let requirement: String

    init(sleepSwitch: SleepSwitch, requirement: String) {
        self.sleepSwitch = sleepSwitch
        self.requirement = requirement
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.setCodeSigningRequirement(requirement)
        let client = Client(sleepSwitch: sleepSwitch)
        connection.exportedInterface = NSXPCInterface(with: LidHelperProtocol.self)
        connection.exportedObject = client
        // Quitting, crashing, or being killed all close the connection, which releases the hold.
        connection.invalidationHandler = { [sleepSwitch] in _ = sleepSwitch.set(ObjectIdentifier(client), holding: false) }
        connection.resume()
        return true
    }
}

/// The team that signed this helper, which must also have signed Bustelo. `nil` for ad-hoc builds.
private func ownTeamID() -> String? {
    var code: SecCode?
    var staticCode: SecStaticCode?
    var info: CFDictionary?
    guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
          SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
          SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess
    else { return nil }
    return (info as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String
}

// The helper ships inside Bustelo.app, so the main bundle is the app itself.
guard let appBundleID = Bundle.main.bundleIdentifier else {
    log.fault("Not running from inside Bustelo.app")
    exit(1)
}
let label = LidHelper.label(appBundleID: appBundleID)
let sleepSwitch = SleepSwitch(marker: URL(fileURLWithPath: "/Library/Application Support/\(label)/SleepDisabled"))
let delegate = Listener(sleepSwitch: sleepSwitch,
                        requirement: LidHelper.clientRequirement(appBundleID: appBundleID, teamID: ownTeamID()))
let listener = NSXPCListener(machServiceName: label)
listener.delegate = delegate
listener.resume()

// launchd sends SIGTERM at shutdown and when Bustelo removes the helper.
signal(SIGTERM, SIG_IGN)
let termination = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
termination.setEventHandler {
    sleepSwitch.releaseAll()
    exit(0)
}
termination.resume()
dispatchMain()
