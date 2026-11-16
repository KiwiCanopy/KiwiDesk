import CoreGraphics

/// Where the pocket's handle sits along an edge (#761, #2678):
/// one band the length of a Dock tile. A bar's handle runs along
/// its bar instead (#3349). Pure.
public enum ShelfMarkPlacement {
    /// The pocket handle's band length along its edge (owner,
    /// 2026-10-19): about a Dock tile, the handle plus a margin a
    /// sideways flick lands in.
    public static let bandLength: CGFloat = 64

    /// Where a band `length` long starts at `position` percent along
    /// an edge running `low...high`, kept whole on the edge: the
    /// pocket's handle and a look's picture of its mark (#1740).
    public static func bandStart(
        position: CGFloat,
        low: CGFloat,
        high: CGFloat,
        length: CGFloat
    ) -> CGFloat {
        let share = max(0, min(position, 100)) / 100
        return min(
            max(low + (high - low) * share - length / 2, low),
            max(high - length, low)
        )
    }

    /// The pocket handle's band on an Auto edge `length` long, as
    /// offsets from its start: centred on `slot`, the slot the
    /// pocket takes on the shown shelf, so it is where the pocket
    /// shows (owner, device 2026-10-29), kept whole on the edge.
    public static func pocketBand(
        slot: ClosedRange<CGFloat>,
        length: CGFloat
    ) -> ClosedRange<CGFloat> {
        let middle = (slot.lowerBound + slot.upperBound) / 2
        let start = min(
            max(middle - bandLength / 2, 0),
            max(length - bandLength, 0)
        )
        return start...(start + bandLength)
    }
}
