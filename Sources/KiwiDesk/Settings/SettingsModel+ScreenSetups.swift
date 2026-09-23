import Foundation
import KiwiDeskCore

/// One screen setup (#1530) a profile could take: its monitors,
/// the profile holding it now, and whether it is connected.
struct ScreenSetupChoice: Identifiable, Equatable {
    let monitors: [String]
    let owner: String?
    let isConnected: Bool
    var id: [String] { monitors }
}

/// Screen setups on the Profiles page (#1530): which a profile
/// could take, how one is named, and the take itself.
extension SettingsModel {
    /// Whether `monitors` is the connected setup.
    func isConnectedSetup(_ monitors: [String]) -> Bool {
        monitors.sorted() == displays.map(\.fingerprint).sorted()
    }

    /// Setups `name` could take — every setup its screen count's
    /// profiles hold plus the connected one, minus its own — the
    /// connected one first, then by the profile holding each.
    func claimableSetups(for name: String) -> [ScreenSetupChoice] {
        let own = Set(
            profileSummaries.first { $0.name == name }?.sets ?? []
        )
        return core.claimableMonitorSets(for: name)
            .filter { !own.contains($0) }
            .map { monitors in
                ScreenSetupChoice(
                    monitors: monitors,
                    owner: profileSummaries.first {
                        $0.sets.contains(monitors)
                    }?.name,
                    isConnected: isConnectedSetup(monitors)
                )
            }
            .sorted {
                if $0.isConnected != $1.isConnected {
                    return $0.isConnected
                }
                return ($0.owner ?? "") < ($1.owner ?? "")
            }
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

    /// A setup's screens as one line: each connected screen by its
    /// name, a disconnected one by its fingerprint's name part.
    /// `distinct` keeps the size where a same-named pair would
    /// otherwise read alike.
    func setupLabel(
        _ monitors: [String],
        distinct: Bool = false
    ) -> String {
        monitors.map { fingerprint in
            let connected = displays.first {
                $0.fingerprint == fingerprint
            }?.name
            guard !distinct else {
                return Self.fingerprintLabel(fingerprint, sized: true)
            }
            return connected
                ?? Self.fingerprintLabel(fingerprint, sized: false)
        }
        .joined(separator: ", ")
    }

    /// Labels for a list of setups, sized only where two would
    /// otherwise read the same.
    func setupLabels(_ sets: [[String]]) -> [String] {
        let plain = sets.map { setupLabel($0) }
        return sets.indices.map { index in
            plain.filter { $0 == plain[index] }.count > 1
                ? setupLabel(sets[index], distinct: true)
                : plain[index]
        }
    }

    /// `Name:WxH` → `Name`, or `Name (WxH)` when `sized`.
    static func fingerprintLabel(
        _ fingerprint: String,
        sized: Bool
    ) -> String {
        guard let colon = fingerprint.lastIndex(of: ":") else {
            return fingerprint
        }
        let name = String(fingerprint[..<colon])
        let size = fingerprint[fingerprint.index(after: colon)...]
        return sized ? "\(name) (\(size))" : name
    }
}
