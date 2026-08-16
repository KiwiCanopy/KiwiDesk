/// The **"+N" grammar's count half** — how many of a capped run
/// to draw, and therefore how many the marker counts.
///
/// `docs/ui-patterns.md` ▸ "+N" declares this one grammar
/// ("**+N** means the same thing wherever it appears… a new
/// surface must not invent a different one") and states three
/// clauses: it counts the items NOT shown rather than the total,
/// **it takes a slot of its own so it never claims to hide
/// exactly one**, and it is an affordance wherever the hidden
/// items have controls of their own.
///
/// The middle clause is arithmetic, and it was written twice —
/// `MonitorCardChips.split` derived it from a card's measured
/// capacity, and the Profiles row pips restated it against a
/// fixed slot count (#789). Both copies were pinned by their own
/// guard, which is exactly the case `.claude/rules/tests.md`
/// admits sharing for: the copies were **of the rule under
/// guard**, so retuning one leaves the other green on the retired
/// rule while both read as covering the same promise.
///
/// A shared *rule*, not a shared *look*: what each caller draws
/// and how it measures its own capacity stay local. Callers pass
/// their capacities in, which is also what lets the guard assert
/// the grammar at capacities no surface ships.
///
/// Deliberately NOT swept into two further sites yet:
/// `HomeCardPreview.profileChips` and `HomeCardSpacesTile` both
/// compute overflow as `total - cap`, so both can render "+1" —
/// a real violation of the middle clause, but routing them
/// CHANGES what Home draws rather than preserving it, so it is
/// its own change with its own eye-confirm.
enum OverflowSplit {
    /// How many items to draw.
    ///
    /// - `count`: how many exist. Clamped at zero, so a
    ///   hand-edited nonsense value cannot produce a negative
    ///   run for a caller to trap on.
    /// - `capacity`: how many fit when NO marker is drawn.
    /// - `markerCapacity`: how many fit once the marker has
    ///   taken its slot. Never greater than `capacity`.
    ///
    /// Everything fits → draw everything and the marker never
    /// appears. Otherwise the marker takes its slot, and if that
    /// would leave exactly one item hidden the run gives up one
    /// more: a marker reading "+1" occupies a slot that would
    /// have shown the very item it is counting.
    static func shown(
        of count: Int,
        fitting capacity: Int,
        withMarker markerCapacity: Int
    ) -> Int {
        guard count > capacity else { return max(count, 0) }
        var shown = markerCapacity
        if count - shown == 1 { shown -= 1 }
        return max(0, shown)
    }
}
