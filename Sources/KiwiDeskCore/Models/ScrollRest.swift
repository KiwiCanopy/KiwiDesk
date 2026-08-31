import CoreGraphics

/// Viewport rest state capturing scroll offset and measured focus slot
/// (`ScrollingLayout.offset`, `heldBase`, #66, #966, #677, #141).
public struct ScrollRest: Sendable, Equatable {
    /// Focus slot measurement provenance for viewport anchor calculations
    /// (#966).
    public struct Slot: Sendable, Equatable {
        /// Focused window ID when offset was measured.
        public var window: WindowID
        /// Window position along scroll axis in the row.
        public var position: CGFloat
        /// Border slot rested against when offset was measured (#966).
        public var restingOn: Border?

        public init(
            window: WindowID,
            position: CGFloat,
            restingOn: Border?
        ) {
            self.window = window
            self.position = position
            self.restingOn = restingOn
        }
    }

    /// Viewport border alignment enum.
    public enum Border: Sendable, Equatable {
        case leading
        case trailing
    }

    /// Viewport scroll offset.
    public var offset: CGFloat
    /// Slot offset was measured against (nil if unmeasured or carried).
    public var slot: Slot?

    public init(offset: CGFloat, slot: Slot? = nil) {
        self.offset = offset
        self.slot = slot
    }

    /// Constructs rest state with measured focus slot
    /// (`ScrollSlotDomain`, #966).
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
