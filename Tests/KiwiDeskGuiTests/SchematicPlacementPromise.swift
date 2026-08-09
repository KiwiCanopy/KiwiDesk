import KiwiDeskCore

/// What the four spawn placements promise a reader of a layout
/// schematic, stated once (#702, #753).
///
/// A stateless primitive with no assertions of its own — the
/// suites keep their own `check` wrappers. It is shared rather
/// than copied because **the copies would be of the rule under
/// guard**: `LayoutSchematicPlacementTests` and
/// `LayoutSchematicScrollingTests` both hold a schematic to this
/// promise, and retuning it in one leaves the other green on the
/// old one — the divergence-weakens-a-guard ground
/// `.claude/rules/tests.md` admits a shared helper on. The split
/// itself was forced by the 350-line file ceiling, so the two
/// suites cannot simply be one.
///
/// Deliberately shares no code with the engine or with
/// `SchematicPlacement`: asserting that a schematic *calls* the
/// helper would pass on one that called it and drew a constant.
enum SchematicPlacementPromise {
    /// Where the `+` lands, at the altitude the preview is read
    /// at — the row's start, its end, or immediately beside the
    /// focused tile. `focus` is where the focused tile **ends
    /// up**: a landing at or before it moves it one slot along,
    /// and a preview that forgets that is #702.
    static func expectedSlot(
        _ placement: SpawnPlacement,
        focus: Int,
        slots: ClosedRange<Int>
    ) -> Int {
        switch placement {
        case .first: return slots.lowerBound
        case .last: return slots.upperBound
        case .beforeFocused: return focus - 1
        case .afterFocused: return focus + 1
        }
    }
}
