import CoreGraphics
import Foundation

/// The crossing between stored, number-keyed Screen pins and the
/// runtime's fingerprint-keyed `spacePins` (#3647): every read of a
/// stored map into the runtime and every capture back goes through
/// the one `liveScreenOrder`.
extension KiwiCore {
    /// Which connected screen holds which number: the live
    /// profile's set covering the screens, in its stored order, else
    /// a set they contain or share screens with continued, else left
    /// to right, ties top to bottom (`screenOrder(holding:)`); the
    /// session's renumber, else the fit rule's order, over either.
    /// Read from adoption state, never the file (#1245); while an
    /// apply installs another arrangement, that arrangement's order.
    public var liveScreenOrder: ScreenOrder {
        profiles.screenOrderInFlight
            ?? sessionScreenOrder
            ?? liveFittedScreenOrder
            ?? screenOrder(holding: profiles.active?.monitorSets ?? [])
    }

    /// The order `profile`'s pins are numbered in on the connected
    /// screens: the session's renumber for the live profile, else its
    /// fit, else `screenOrder(holding:)`. A draft of a stored
    /// profile reads its own, never the live one's.
    public func screenOrder(for profile: Profile?) -> ScreenOrder {
        if let profile,
            let order = sessionScreenOrder(for: profile.name)
                ?? fittedScreenOrder(
                    for: profile.name,
                    holding: profile.monitorSets
                )
        {
            return order
        }
        return screenOrder(holding: profile?.monitorSets ?? [])
    }

    /// The order `sets` number the connected screens in: the set
    /// covering them, else one they contain or share screens with
    /// continued, else left to right (#3648); read on each call, so
    /// it follows a screen change. The one door a base order is
    /// decided at.
    public func screenOrder(holding sets: [MonitorSet]) -> ScreenOrder {
        let displays = state.workspaces.allDisplays
        return sets.order(matching: liveFingerprints)
            ?? .continuing(sets, displays: displays)
            ?? .leftToRight(displays)
    }

    /// `profile`'s pins as the runtime keys them on the connected
    /// screens, through its order: a setup it does not hold is
    /// numbered by `screenOrder(holding:)`, so its pins apply there
    /// too (#3647 ▸ lane 2). The one door every apply takes.
    func runtimePins(of profile: Profile) -> [SpaceID: String] {
        screenOrder(for: profile).runtime(profile.spaceMonitorMap)
    }

    /// `displays` that hold a number, in Screen N order, each with
    /// it: what a number in Lua or the CLI, `list_monitors` and
    /// `desktop_change` name (#3647). The number is the screen's
    /// place in `liveScreenOrder`; twins take theirs left to right,
    /// ties top to bottom.
    func numberedScreens(
        _ displays: [Display]
    ) -> [(number: Int, display: Display)] {
        var left = displays.sorted(by: ScreenOrder.precedes)
        var result: [(number: Int, display: Display)] = []
        let order = liveScreenOrder
        for (index, fingerprint) in order.fingerprints.enumerated() {
            guard
                let at = left.firstIndex(where: {
                    $0.fingerprint == fingerprint
                })
            else { continue }
            result.append((index + 1, left.remove(at: at)))
        }
        return result
    }

    /// The connected screen numbered `number`, nil where none is.
    func screen(numbered number: Int) -> Display? {
        numberedScreens(state.workspaces.allDisplays)
            .first { $0.number == number }?.display
    }

    /// The number of the connected screen `id`, nil where it holds
    /// none.
    func screenNumber(of id: DisplayID) -> Int? {
        numberedScreens(state.workspaces.allDisplays)
            .first { $0.display.id == id }?.number
    }

    /// The live pins a write records, numbered on the live screens;
    /// a number `stored` holds past them stays.
    func storedPins(
        alsoOf extra: Set<SpaceID> = [],
        over stored: [SpaceID: ScreenSlotKey] = [:]
    ) -> [SpaceID: ScreenSlotKey] {
        liveScreenOrder.storing(
            runtime: capturedPins(alsoOf: extra),
            over: stored
        )
    }

    /// `stored` as the runtime keys it on the live screens.
    func runtimePins(
        _ stored: [SpaceID: ScreenSlotKey]
    ) -> [SpaceID: String] {
        liveScreenOrder.runtime(stored)
    }

    /// The connected screens as a set a write adds stores them: the
    /// session's renumber, else the order the setup is held in or
    /// numbered by, never the fit rule's (#3647 ▸ no-fit ruling 4).
    var liveMonitorSet: MonitorSet {
        MonitorSet(
            monitors: (sessionScreenOrder
                ?? screenOrder(holding: profiles.active?.monitorSets ?? []))
                .fingerprints
        )
    }

    /// The connected screens' set as a profile already holds it, in
    /// its stored order; nil where none does.
    var heldLiveSet: MonitorSet? {
        let live = liveFingerprints
        return live.isEmpty ? nil : heldSet(matching: live)
    }

    /// The set covering `monitors` as the profile holding it stores
    /// it — the order a claim or a create keeps (#3647).
    func heldSet(matching monitors: [String]) -> MonitorSet? {
        profiles.allProfiles().lazy
            .compactMap { $0.set(matching: monitors) }.first
    }
}
