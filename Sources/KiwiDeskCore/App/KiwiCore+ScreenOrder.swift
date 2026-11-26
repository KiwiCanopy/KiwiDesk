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
        let live = liveFingerprints
        if let set = profiles.active?.monitorSets.first(where: {
            $0.matches(live)
        }) {
            return set.order
        }
        return .leftToRight(state.workspaces.allDisplays)
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
}
