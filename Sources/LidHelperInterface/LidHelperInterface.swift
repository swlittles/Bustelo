import Foundation

/// What Bustelo asks its lid helper, the small root daemon that runs `pmset disablesleep`.
@objc(BusteloLidHelperProtocol)
public protocol LidHelperProtocol {
    /// While any connected Bustelo holds this, closing the lid doesn't sleep the Mac.
    /// Disconnecting releases the hold, so a quit or crash can't leave sleep disabled.
    func setLidSleepDisabled(_ disabled: Bool, reply: @escaping (Bool) -> Void)
}

public enum LidHelper {
    /// The launchd label and Mach service name. Derived from the app's bundle ID,
    /// so development and release builds each get their own helper.
    public static func label(appBundleID: String) -> String { "\(appBundleID).LidHelper" }

    /// Only Bustelo may connect. Signed builds also require the helper's own Developer ID team;
    /// ad-hoc development builds have no team, so they check the identifier alone.
    public static func clientRequirement(appBundleID: String, teamID: String?) -> String {
        guard let teamID, !teamID.isEmpty else { return "identifier \"\(appBundleID)\"" }
        return "anchor apple generic and identifier \"\(appBundleID)\" and certificate leaf[subject.OU] = \"\(teamID)\""
    }

    /// Reads `SleepDisabled` from `pmset -g`, which lists it only while it's set.
    public static func sleepDisabled(pmsetOutput: String) -> Bool {
        pmsetOutput.split(separator: "\n").contains {
            let fields = $0.split(whereSeparator: \.isWhitespace)
            return fields.first == "SleepDisabled" && fields.last == "1"
        }
    }
}
