import AppKit
import Foundation

/// The float tier of directional `focus` (#488), split from
/// `KiwiCore+NavigateCommand` for file size.
extension KiwiCore {
    /// The nearest floating window in `direction`, consulted
    /// ONLY after the tiled candidate search found nothing —
    /// tiled candidates always win, so tile-to-tile navigation
    /// is byte-identical to the pre-#488 behavior. Never for
    /// `swap`: a floating window has no slot or array position
    /// to trade, so a swap's dead end stays a dead end.
    ///
    /// Candidates come from
    /// `StateCoordinator.floatingFocusCandidates` and navigate
    /// by LIVE frame — floats have no slot. A float parked at
    /// a coincident center (a stale toggle left it exactly on a
    /// tiled slot) stays unreachable: no direction points at a
    /// zero offset (see `docs/accepted-limitations.md`); cycle
    /// or click reaches it.
    func floatTierTarget(
        from origin: CGRect,
        in direction: Direction,
        space: Space,
        focused: WindowID,
        swapping: Bool
    ) -> WindowID? {
        guard !swapping else { return nil }
        let candidates = state.floatingFocusCandidates(
            of: space,
            activeSpace: space.id
        )
        .filter { $0 != focused }
        .compactMap { id -> (WindowID, CGRect)? in
            guard let frame = state.windows[id]?.frame,
                !frame.isEmpty
            else { return nil }
            return (id, frame)
        }
        return Navigation.neighbor(
            from: origin,
            in: direction,
            candidates: candidates
        )
    }
}
