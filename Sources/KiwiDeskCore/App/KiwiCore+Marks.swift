import AppKit

/// The two on-window mark families — the sticky mark (#414) and the
/// overflow mark (#2235) — ride every channel together, so each
/// channel has one door here and no call site names one family
/// alone (`MarkFamilyParityTests`).
extension KiwiCore {
    /// Re-syncs both families; `reassertOrder` re-stacks every mark,
    /// as the settle passes do for the rings (#2026).
    func updateMarks(reassertOrder: Bool = false) {
        updateStickyMarks(reassertOrder: reassertOrder)
        updateOverflowMarks(reassertOrder: reassertOrder)
    }

    /// Follows a moving window's frame for both families
    /// (`FollowSource.renderFrame`, #285, #594, #677).
    func followMarks(
        _ id: WindowID,
        windowFrame: CGRect,
        source: FollowSource,
        pin: SizePin?
    ) {
        stickyMarks.follow(
            id,
            windowFrame: windowFrame,
            source: source,
            pin: pin
        )
        overflowMarks.follow(
            id,
            windowFrame: windowFrame,
            source: source,
            pin: pin
        )
    }

    /// Owes both families' marks on `id` a stack at the next sync:
    /// the window was carried to another Desktop (#2026).
    func oweMarkOrder(_ id: WindowID) {
        stickyMarks.oweOrder(id)
        overflowMarks.oweOrder(id)
    }
}
