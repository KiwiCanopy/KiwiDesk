import CoreGraphics

extension ShelfArrangement {
    /// What the section divider's drag moves (#1517, ruling 15),
    /// present only while the shelf is full: the room both
    /// sections share, the Space section's drawn length, the floor
    /// the configured minimum resolves to, the range
    /// `minimumRange` lets it take, and which section leads.
    public struct Divider: Equatable, Sendable {
        public var room: CGFloat
        public var spaceLength: CGFloat
        public var minimumLength: CGFloat
        public var bounds: ClosedRange<CGFloat>
        public var spacesFirst: Bool

        public init(
            room: CGFloat,
            spaceLength: CGFloat,
            minimumLength: CGFloat,
            bounds: ClosedRange<CGFloat>,
            spacesFirst: Bool
        ) {
            self.room = room
            self.spaceLength = spaceLength
            self.minimumLength = minimumLength
            self.bounds = bounds
            self.spacesFirst = spacesFirst
        }

        /// The Space Bar minimum, in percent, that puts the
        /// divider `delta` points further along the edge than it
        /// sat when the drag began — the length clamped to what
        /// the shelf lets the Space section take. Where the App
        /// section's own need, not the minimum, holds the divider,
        /// a drag that leaves it there leaves the minimum as
        /// configured. The minimum's own range is the setting's one
        /// clamp (`KiwiShelfCommandSetting`); nil on an empty shelf.
        public func minimum(afterDragging delta: CGFloat) -> CGFloat? {
            guard room > 0 else { return nil }
            let signed = spacesFirst ? delta : -delta
            let target = min(
                max(spaceLength + signed, bounds.lowerBound),
                bounds.upperBound
            )
            let held = minimumLength < spaceLength - 0.5
            let length =
                held && target <= spaceLength ? minimumLength : target
            return length / room * 100
        }
    }
}

extension KiwiShelf {
    /// The minimum a double-click on the divider restores: Core's
    /// default, not a profile's authored value — the same live
    /// write the drag makes (an open question with #1517's owner).
    public static var resetMinimum: CGFloat { KiwiShelf().minimum }
}
