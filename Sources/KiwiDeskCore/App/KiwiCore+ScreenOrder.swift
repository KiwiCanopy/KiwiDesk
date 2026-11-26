import CoreGraphics
import Foundation

/// The crossing between stored, number-keyed Screen pins and the
/// runtime's fingerprint-keyed `spacePins` (#3647): every read of a
/// stored map into the runtime and every capture back goes through
/// the one `liveScreenOrder`.
extension KiwiCore {
    /// Which connected screen holds which number: the live
    /// profile's set covering the screens, in its stored order, else
    /// left to right, ties top to bottom. Read from adoption state,
    /// never the file (#1245).
    public var liveScreenOrder: ScreenOrder {
        sessionScreenOrder
            ?? screenOrder(holding: profiles.active?.monitorSets ?? [])
    }

    /// The order `profile`'s pins are numbered in on the connected
    /// screens: the session's renumber for the live profile, else its
    /// set covering them, else left to right. A draft of a stored
    /// profile reads its own, never the live one's.
    public func screenOrder(for profile: Profile?) -> ScreenOrder {
        if let profile, let order = sessionScreenOrder(for: profile.name) {
            return order
        }
        return screenOrder(holding: profile?.monitorSets ?? [])
    }

    /// The order `sets` number the connected screens in; read on each
    /// call, so it follows a screen change.
    public func screenOrder(holding sets: [MonitorSet]) -> ScreenOrder {
        sets.order(matching: liveFingerprints)
            ?? .leftToRight(state.workspaces.allDisplays)
    }

    /// `profile`'s pins as the runtime keys them on the connected
    /// screens, through its order: a setup it does not hold is
    /// numbered left to right, so its pins apply there too (#3647
    /// ▸ lane 2). The one door every apply takes.
    func runtimePins(of profile: Profile) -> [SpaceID: String] {
        screenOrder(for: profile).runtime(profile.spaceMonitorMap)
    }

    /// `displays` that hold a number, in Screen N order, each with
    /// it: what a number in Lua or the CLI, `list_monitors` and
    /// `desktop_change` name (#3647). The number is the screen's
    /// place in `liveScreenOrder`, so a gap stays a gap; twins take
    /// theirs left to right, ties top to bottom.
    func numberedScreens(
        _ displays: [Display]
    ) -> [(number: Int, display: Display)] {
        var left = displays.sorted(by: ScreenOrder.precedes)
        var result: [(number: Int, display: Display)] = []
        let order = liveScreenOrder
        for (index, fingerprint) in order.fingerprints.enumerated()
        where order.holds(ScreenSlotKey(number: index + 1)!) {
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

    /// The connected screens as a set a write adds stores them: in
    /// the order the live pins were numbered in.
    var liveMonitorSet: MonitorSet {
        MonitorSet(monitors: liveScreenOrder.fingerprints)
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
