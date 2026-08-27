import CoreGraphics

/// Where the scrolling viewport last came to rest — the offset
/// **and** the focused slot it was measured against (#66, #966).
///
/// The offset alone is an absolute distance along a row whose
/// slots all share one size, so anything that changes that size
/// (a `resize`, a `scroll.set_slot_size`, a learned #677 bound)
/// moves every slot underneath it: the same number now points at
/// a different place in the row. `follow` — the one anchor that
/// reads the prior offset — then held a position nobody asked it
/// to hold, and the focused window drifted toward the leading
/// edge while the freed space opened behind it (#966).
///
/// Carrying the measurement with the offset is what lets
/// `ScrollingLayout.offset` tell the two causes apart: the focus
/// moved (hold the offset, pan minimally — the #66 contract), or
/// the row moved underneath an unchanged focus (hold that slot's
/// place on screen). A rest with no `slot` — seeded by hand, or
/// recorded on a pass that had no slot to measure against —
/// always reads as the first case, which is what every anchor did
/// before this type existed.
///
/// Ephemeral, like `Space.stackWeights`: never persisted, cleared
/// on an actual mode change.
public struct ScrollRest: Sendable, Equatable {
    /// The focused slot an offset was measured against, recorded
    /// as one value so an offset can never travel with another
    /// pass's provenance.
    public struct Slot: Sendable, Equatable {
        /// The window focused when the offset was computed.
        public var window: WindowID
        /// That window's position along the scroll axis, in the
        /// row as it stood then.
        public var position: CGFloat

        public init(window: WindowID, position: CGFloat) {
            self.window = window
            self.position = position
        }
    }

    /// The viewport offset itself: the ideal, unpinned value the
    /// last tile chose (frames may pin, the offset never does).
    public var offset: CGFloat
    /// The slot `offset` was measured against, or nil when that
    /// pass placed no slot (a floating focus, nothing focused).
    public var slot: Slot?

    public init(offset: CGFloat, slot: Slot? = nil) {
        self.offset = offset
        self.slot = slot
    }

    /// The rest for an `offset` measured against `window` sitting
    /// at `position` along the row.
    public init(
        offset: CGFloat,
        focus window: WindowID,
        position: CGFloat
    ) {
        self.offset = offset
        self.slot = Slot(window: window, position: position)
    }
}
