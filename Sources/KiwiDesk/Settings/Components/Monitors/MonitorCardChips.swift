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
    /// The gap `WrapChips` lays chips out with — read from
    /// `ChipMetrics`, which owns it, since this arithmetic is its
    /// consumer rather than its source.
    static var spacing: CGFloat { ChipMetrics.spacing }
    /// The card's own padding, and the header line above the
    /// chips. `headerHeight` is the CARD's — the tray's header is
    /// unsized `.caption2` and passes its own, rather than
    /// inheriting a number that happens to be close.
    static let cardPadding: CGFloat = 6
    static let headerHeight: CGFloat = 16
    static let trayHeaderHeight: CGFloat = 14
    /// The gap the chip stack puts between its children.
    ///
    /// Counted, not ignored: leaving it out overstated the chip
    /// area at EVERY card size, so `capacity` could return one row
    /// too many and that row clipped — reintroducing the clip the
    /// `+n` exists to prevent (code review, 2026-08-04). The card
    /// and the tray both lay their stacks out with THIS constant
    /// and hold exactly two children, so one gap is the whole of
    /// it; a third child would be a second gap this arithmetic
    /// does not know about, which is why
    /// `MonitorsGateWiringTests` pins the stacks to it.
    static let stackSpacing: CGFloat = 2
    /// The `+n` marker's own width — a capsule around a two- or
    /// three-character label.
    ///
    /// It is a COLUMN, not a slot: the marker sits beside the
    /// wrapped chips, so it narrows every row rather than
    /// consuming one chip's worth once. Reserving it per card
    /// instead let three chips flow into three rows inside a band
    /// sized for two, and the last row was clipped with its clear
    /// button and its menu (code review, 2026-08-04).
    static let markerWidth: CGFloat = 34

    /// The chip area inside a card of `size`, given the header
    /// above it.
    static func chipArea(
        in size: CGSize,
        header: CGFloat = headerHeight
    ) -> CGSize {
        CGSize(
            width: max(0, size.width - cardPadding * 2),
            height: max(
                0,
                size.height - cardPadding * 2 - header
                    - stackSpacing
            )
        )
    }

    /// How many chips a card of `size` can show at once — at
    /// least one, because `MonitorArrangement.minimumCard` is
    /// derived from exactly that promise.
    ///
    /// `reservingMarker` narrows the row by the `+n` column, for
    /// the case where there is going to be one.
    static func capacity(
        in size: CGSize,
        header: CGFloat = headerHeight,
        reservingMarker: Bool = false
    ) -> Int {
        let area = chipArea(in: size, header: header)
        let rows = max(
            1,
            Int((area.height + spacing) / (chipHeight + spacing))
        )
        let usable =
            reservingMarker
            ? area.width - markerWidth - spacing : area.width
        // Zero is a real answer WITH the marker reserved: a card
        // at the floor has room for one chip OR the `+n`, not
        // both, and it must then show the marker alone rather
        // than a chip the marker pushes off the edge. Without it
        // the plain capacity is at least one, because
        // `MonitorArrangement.minimumCard` promises exactly that.
        let perRow = max(
            reservingMarker ? 0 : 1,
            Int((usable + spacing) / (minChipWidth + spacing))
        )
        return rows * perRow
    }

    /// Splits a card's chips into the ones it draws and the count
    /// hiding behind the `+n`.
    ///
    /// Two things this owes its callers. The marker is a COLUMN,
    /// so the capacity it is measured against reserves one —
    /// see `capacity(in:header:reservingMarker:)`. And it never
    /// names exactly ONE hidden chip: a card that would hide one
    /// shows one fewer instead, so the count is always 0 or ≥ 2.
    /// `monitor_card.more_spaces.axlabel` has no singular, and
    /// `MonitorCardChipsTests` pins the property rather than the
    /// two counts that happen to occur.
    static func split<Chip>(
        _ chips: [Chip],
        in size: CGSize,
        header: CGFloat = headerHeight
    ) -> (shown: [Chip], overflow: Int) {
        guard chips.count > capacity(in: size, header: header)
        else { return (chips, 0) }
        var shown = capacity(
            in: size,
            header: header,
            reservingMarker: true
        )
        if chips.count - shown == 1 { shown -= 1 }
        shown = max(0, shown)
        return (Array(chips.prefix(shown)), chips.count - shown)
    }
}
