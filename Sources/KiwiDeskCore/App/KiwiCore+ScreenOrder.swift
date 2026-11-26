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
        screenOrder(holding: profiles.active?.monitorSets ?? [])
    }

    /// The order `profile`'s pins are numbered in on the connected
    /// screens: its set covering them, else left to right. A draft of
    /// a stored profile reads its own, never the live one's.
    public func screenOrder(for profile: Profile?) -> ScreenOrder {
        screenOrder(holding: profile?.monitorSets ?? [])
    }

    /// The order `sets` number the connected screens in; read on each
    /// call, so it follows a screen change.
    public func screenOrder(holding sets: [MonitorSet]) -> ScreenOrder {
        sets.order(matching: liveFingerprints)
            ?? .leftToRight(state.workspaces.allDisplays)
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
