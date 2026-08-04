import CoreGraphics

/// How many space chips fit inside a display card, and what
/// happens to the ones that do not (#678 Phase 3, turn 13b).
///
/// A card's SIZE comes from the monitor and its chip COUNT comes
/// from the config, so the two can disagree — and the first cut
/// resolved that disagreement by clipping, which deletes the
/// chip along with its clear button and its drag handle. Those
/// are the only ways back out of a pin, so clipping hides a
/// user's own configuration from them (`docs/design-decisions.md`
/// — config presence expands the surface, it never shrinks it).
///
/// So the overflow is COUNTED instead: the last visible slot
/// becomes a `+n` chip whose popover holds the rest, affordances
/// intact.
///
/// The metrics are stated here rather than at the drawing,
/// because two other things derive from them —
/// `MonitorArrangement.minimumCard` (a card may never be drawn
/// too small to hold one chip) and this capacity — and a floor
/// that drifted from the chip it exists to fit would stop
/// flooring anything.
enum MonitorCardChips {
    /// A chip's drawn height: the caption line plus its vertical
    /// padding, top and bottom (`SpaceAssignmentChip`).
    static let chipHeight: CGFloat = 22
    /// The narrowest a chip gets — horizontal padding either
    /// side, a one-character name, and the clear button's hit
    /// target. A longer name makes it wider, so a capacity
    /// computed from this is an UPPER bound on how many fit;
    /// erring that way keeps the card honest, since a `+n` that
    /// appears one chip early costs nothing and a chip that
    /// silently does not fit costs the affordance.
    static let minChipWidth: CGFloat = 52
    /// The gap `WrapChips` lays chips out with.
    static let spacing: CGFloat = 6
    /// The card's own padding, and the header line above the
    /// chips.
    static let cardPadding: CGFloat = 6
    static let headerHeight: CGFloat = 16

    /// The chip area inside a card of `size`.
    static func chipArea(in size: CGSize) -> CGSize {
        CGSize(
            width: max(0, size.width - cardPadding * 2),
            height: max(
                0,
                size.height - cardPadding * 2 - headerHeight
            )
        )
    }

    /// How many chips a card of `size` can show at once — at
    /// least one, because `MonitorArrangement.minimumCard` is
    /// derived from exactly that promise.
    static func capacity(in size: CGSize) -> Int {
        let area = chipArea(in: size)
        let rows = max(
            1,
            Int((area.height + spacing) / (chipHeight + spacing))
        )
        let perRow = max(
            1,
            Int(
                (area.width + spacing) / (minChipWidth + spacing)
            )
        )
        return rows * perRow
    }

    /// Splits a card's chips into the ones it draws and the count
    /// hiding behind the `+n`.
    ///
    /// The `+n` chip occupies a slot of its own, so a card at
    /// capacity `n` with `n + 1` chips shows `n - 1` of them —
    /// otherwise the overflow marker would push out a chip it
    /// then failed to mention.
    static func split<Chip>(
        _ chips: [Chip],
        in size: CGSize
    ) -> (shown: [Chip], overflow: Int) {
        let capacity = capacity(in: size)
        guard chips.count > capacity else { return (chips, 0) }
        let shown = max(0, capacity - 1)
        return (Array(chips.prefix(shown)), chips.count - shown)
    }
}
