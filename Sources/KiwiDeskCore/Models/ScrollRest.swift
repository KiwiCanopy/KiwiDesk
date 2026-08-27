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
/// edge (#966).
///
/// Carrying the measurement with the offset is what lets
/// `ScrollingLayout.offset` tell the two causes apart: the focus
/// moved (hold the offset, pan minimally — the #66 contract), or
/// the row moved underneath an unchanged focus (hold that slot's
/// place on screen). A rest with no `slot` — one seeded by hand,
/// or a space that has never placed a slot at all — reads as the
/// first case, which is what every anchor did before this type
/// existed. A pass that places no slot does not MAKE one: it
/// carries the offset through (#141) and its measurement with
/// it, because the pair it was handed still describes the offset
/// it is returning.
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
        /// Which viewport border the slot was resting against
        /// when the offset was measured, or nil for neither —
        /// the edge a resize then has to hold (#966).
        ///
        /// A VERDICT rather than the geometry behind it, and
        /// deliberately: flushness is a fact about the viewport
        /// the offset was measured in, and a bar toggle, a gap
        /// edit or a space changing screens moves that viewport
        /// between passes. Recording the span instead would
        /// leave the consumer comparing a measurement-time
        /// extent against a current-pass `along` — a verdict
        /// about a viewport the slot never sat in. It also keeps
        /// the both-borders precedence at ONE altitude: a slot
        /// filling the viewport records `.leading`, so the
        /// consumer never re-decides which border wins.
        public var restingOn: Border?

        public init(
            window: WindowID,
            position: CGFloat,
            restingOn: Border? = nil
        ) {
            self.window = window
            self.position = position
            self.restingOn = restingOn
        }
    }

    /// A viewport border a slot can rest against.
    public enum Border: Sendable, Equatable {
        case leading
        case trailing
    }

    /// The viewport offset itself: the ideal, unpinned value the
    /// last tile chose (frames may pin, the offset never does).
    public var offset: CGFloat
    /// The slot `offset` was measured against — nil only where
    /// no pass has ever measured one, since a pass that places
    /// no slot carries the previous measurement through with the
    /// offset it is also carrying.
    public var slot: Slot?

    public init(offset: CGFloat, slot: Slot? = nil) {
        self.offset = offset
        self.slot = slot
    }

    /// The rest for an `offset` measured against `window`
    /// sitting at `position` along the row, resting on
    /// `restingOn` (nil for neither border).
    /// `restingOn` takes no default on purpose: it is the one
    /// field nothing else can cross-check, and a recorded
    /// verdict that defaults to something plausible is how a
    /// producer comes to record a constant unnoticed. A
    /// hand-seeded rest with no provenance takes
    /// `ScrollRest(offset:)` instead.
    public init(
        offset: CGFloat,
        focus window: WindowID,
        position: CGFloat,
        restingOn: Border?
    ) {
        self.offset = offset
        self.slot = Slot(
            window: window,
            position: position,
            restingOn: restingOn
        )
    }
}
