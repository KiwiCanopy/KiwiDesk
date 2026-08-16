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
/// guard. Extracting production duplication is AGENTS.md §2.4's
/// call, and here it goes past "a small readable duplication"
/// for a specific reason: the copies were of the rule UNDER
/// GUARD, so retuning one would leave the other green on the
/// retired rule while both read as covering the same promise.
///
/// A shared *rule*, not a shared *look*: what each caller draws
/// and how it measures its own capacity stay local. Callers pass
/// their capacities in, which is also what lets the guard assert
/// the grammar at capacities no surface ships.
///
/// **A surface that caps a run routes through this**, rather
/// than computing `total - cap` beside its own drawing. Stated
/// as an obligation and not as a census on purpose: the first
/// draft of this comment named the two unrouted sites it knew
/// about, was wrong the day it was written — there are more, in
/// Home and in the schematics — and had a second copy of the
/// same wrong number in `docs/ui-patterns.md`. A list of who has
/// not adopted a rule yet rots; the rule does not.
///
/// Adopting an existing site is its own change, because routing
/// it CHANGES what that surface draws (a "+1" becomes a "+2"
/// showing one fewer item) rather than preserving it, so each
/// owes an eye-confirm.
enum OverflowSplit {
    /// How many items to draw.
    ///
    /// - `count`: how many exist. Clamped at zero, so a
    ///   hand-edited nonsense value cannot produce a negative
    ///   run for a caller to trap on.
    /// - `capacity`: how many fit when NO marker is drawn.
    /// - `markerCapacity`: how many fit once the marker has
    ///   taken its slot. CLAMPED to `capacity` rather than
    ///   documented as a precondition — a caller passing a
    ///   larger one would otherwise get `shown > count` and hand
    ///   its own caller a negative overflow, and a stated
    ///   obligation no guard can see is how that ships.
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
        var shown = min(markerCapacity, capacity)
        if count - shown == 1 { shown -= 1 }
        return max(0, shown)
    }
}
