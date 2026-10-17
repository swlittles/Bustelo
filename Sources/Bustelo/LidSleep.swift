import Foundation
import LidHelperInterface
import ServiceManagement

/// Keeps closing the lid from sleeping the Mac.
///
/// Power assertions can't do this, so a small helper that launchd runs as root
/// sets `pmset disablesleep`. The helper keeps it set only while Bustelo stays
/// connected and asking, so quitting or crashing restores normal lid sleep.
final class LidSleepGuard {
    /// The helper confirmed that closing the lid won't sleep the Mac.
    private(set) var isHeld = false
    /// The helper couldn't be reached or couldn't change the setting.
    private(set) var lastRequestFailed = false

    private let label: String
    private let service: SMAppService
    private var connection: NSXPCConnection?
    /// What the current connection was asked for; `nil` while disconnected.
    private var requested: Bool?

    init(appBundleID: String = Bundle.main.bundleIdentifier ?? "io.github.swlittles.Bustelo") {
        label = LidHelper.label(appBundleID: appBundleID)
        service = .daemon(plistName: "\(label).plist")
    }

    /// The helper is installed but the user hasn't allowed it under Login Items yet.
    var needsApproval: Bool { service.status == .requiresApproval }

    /// Installs the helper. The first time, macOS asks the user to allow it in Login Items.
    func install() throws {
        guard service.status != .enabled else { return }
        do {
            try service.register()
        } catch {
            // Registering a daemon throws until the user approves it; that's expected.
            guard service.status == .requiresApproval else { throw error }
        }
        if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
    }

    /// Call as often as needed; only a change of mind or a lost connection reaches the helper.
    func hold(_ wanted: Bool) {
        guard wanted != (requested ?? false) else { return }
        guard wanted else {
            // Disconnecting is the release: the helper restores sleep when no Bustelo is asking.
            if let connection { drop(connection, failed: false) }
            return
        }
        // Until the user approves the helper, the next check tries again.
        guard service.status == .enabled else { return }
        let connection = self.connection ?? connect()
        requested = true
        let helper = connection.remoteObjectProxyWithErrorHandler { [weak self] _ in
            DispatchQueue.main.async { self?.drop(connection, failed: true) }
        } as? LidHelperProtocol
        helper?.setLidSleepDisabled(true) { [weak self] held in
            DispatchQueue.main.async {
                guard let self, self.connection === connection else { return }
                self.isHeld = held
                self.lastRequestFailed = !held
            }
        }
    }

    private func connect() -> NSXPCConnection {
        let connection = NSXPCConnection(machServiceName: label, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: LidHelperProtocol.self)
        // If the helper restarts or goes away, the next check reconnects and asks again.
        let lost: () -> Void = { [weak self, weak connection] in
            DispatchQueue.main.async { if let connection { self?.drop(connection, failed: false) } }
        }
        connection.interruptionHandler = lost
        connection.invalidationHandler = lost
        connection.resume()
        self.connection = connection
        return connection
    }

    private func drop(_ connection: NSXPCConnection, failed: Bool) {
        guard self.connection === connection else { return }
        self.connection = nil
        requested = nil
        isHeld = false
        lastRequestFailed = failed
        connection.invalidate()
    }
}
