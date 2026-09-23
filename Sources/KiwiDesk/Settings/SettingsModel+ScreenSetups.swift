import Foundation
import KiwiDeskCore

/// Screen setups on the Profiles page (#1530): Core answers which
/// sets a profile could take and who holds them; this narrates
/// them and performs the take.
extension SettingsModel {
    /// Whether `monitors` is the connected setup.
    func isConnectedSetup(_ monitors: [String]) -> Bool {
        monitors.sorted() == displays.map(\.fingerprint).sorted()
    }

    /// Setups `name` could take, in Core's order (connected first).
    func claimableSetups(for name: String) -> [ClaimableMonitorSet] {
        core.claimableMonitorSets(for: name)
    }

    /// Gives `monitors` to `name`, taking it from the profile that
    /// held it without a warning (ruled, #1530).
    func claimScreenSetup(_ monitors: [String], for name: String) {
        do {
            try core.claimMonitorSet(monitors, for: name)
        } catch {
            profileWarning = L(
                "profiles.save_failed",
                "Saving failed: %1$@",
                "\(error)"
            )
            core.onLog("screen setup claim failed: \(error)")
        }
        refreshProfiles()
    }

    /// A setup's screens as one localized list: a connected screen
    /// by its name, a disconnected one by its fingerprint's name —
    /// with its size where `sized`, so a same-named pair differs.
    func setupLabel(_ monitors: [String], sized: Bool = false) -> String {
        LocalizedList.join(
            monitors.map { fingerprint in
                let parts = Display.fingerprintParts(fingerprint)
                guard !sized else {
                    return "\(parts.name) (\(parts.size))"
                }
                let connected = monitorName(fingerprint)
                return connected == fingerprint ? parts.name : connected
            }
        )
    }

    /// Labels for a list of setups, sized only where two would
    /// otherwise read the same.
    func setupLabels(_ sets: [[String]]) -> [String] {
        let plain = sets.map { setupLabel($0) }
        return sets.indices.map { index in
            plain.filter { $0 == plain[index] }.count > 1
                ? setupLabel(sets[index], sized: true)
                : plain[index]
        }
    }
}
