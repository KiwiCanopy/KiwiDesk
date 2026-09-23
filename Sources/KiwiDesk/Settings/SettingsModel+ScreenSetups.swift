import Foundation
import KiwiDeskCore

/// Screen setups on the Profiles page (#1530): Core answers which
/// sets a profile could take and who holds them; this narrates
/// them and performs the take.
extension SettingsModel {
    /// Whether `monitors` is the connected setup — Core's answer.
    func isConnectedSetup(_ monitors: [String]) -> Bool {
        core.isConnectedMonitorSet(monitors)
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
            adoptClaimedPins()
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

    /// A pick onto the loaded profile moves the LIVE pins (Core
    /// adopts them), so the Live draft's baseline follows, and an
    /// unedited draft with it — or its next Save writes the old
    /// pins back. The pick's one caller is this model
    /// (`MonitorSetClaimSeamTests`' census).
    private func adoptClaimedPins() {
        guard target == .live else { return }
        let live = core.livePins
        if config.spacePins == cleanConfig.spacePins {
            config.spacePins = live
        }
        cleanConfig.spacePins = live
        recomputeDirty()
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

    /// Labels for `sets`, each sized where ANY other setup the
    /// Profiles page shows — every profile's, and the connected
    /// one — would read the same, so one page never names two
    /// setups alike.
    func setupLabels(_ sets: [[String]]) -> [String] {
        let known = Set(
            profileSummaries.flatMap(\.sets).map { $0.sorted() }
                + sets.map { $0.sorted() }
                + [displays.map(\.fingerprint).sorted()]
        )
        var seen: [String: Set<[String]>] = [:]
        for set in known { seen[setupLabel(set), default: []].insert(set) }
        return sets.map { set in
            let plain = setupLabel(set)
            return (seen[plain]?.count ?? 0) > 1
                ? setupLabel(set, sized: true) : plain
        }
    }
}
