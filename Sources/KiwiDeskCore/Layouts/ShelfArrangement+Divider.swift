import CoreGraphics

extension ShelfArrangement {
    /// What the section divider's drag moves (#1517, ruling 15),
    /// present only while the shelf is full: the room both
    /// sections share, the Space section's drawn length, the
    /// length the App section's need leaves it (`free`), the range
    /// `minimumRange` lets it take, and which section leads.
    public struct Divider: Equatable, Sendable {
        public var room: CGFloat
        public var spaceLength: CGFloat
        public var free: CGFloat
        public var bounds: ClosedRange<CGFloat>
        public var spacesFirst: Bool

        public init(
            room: CGFloat,
            spaceLength: CGFloat,
            free: CGFloat,
            bounds: ClosedRange<CGFloat>,
            spacesFirst: Bool
        ) {
            self.room = room
            self.spaceLength = spaceLength
            self.free = free
            self.bounds = bounds
            self.spacesFirst = spacesFirst
        }

        /// The Space Bar minimum, in percent, that puts the
        /// divider `delta` points further along the edge than it
        /// sat when the drag began — or nil where that minimum
        /// would not move the line: a bound, or the App section's
        /// need, holds it, and a drag that moves nothing writes
        /// nothing. The minimum's own range is the setting's one
        /// clamp (`KiwiShelfCommandSetting`).
        public func minimum(afterDragging delta: CGFloat) -> CGFloat? {
            guard room > 0 else { return nil }
            let signed = spacesFirst ? delta : -delta
            let target = min(
                max(spaceLength + signed, bounds.lowerBound),
                bounds.upperBound
            )
            // The length the layout draws for a floor of `target`.
            let drawn = max(target, free)
            guard abs(drawn - spaceLength) >= 0.5 else { return nil }
            return target / room * 100
        }
    }
}

extension KiwiShelf {
    /// The minimum a double-click on the divider restores: Core's
    /// default, not a profile's authored value — the same live
    /// write the drag makes (an open question with #1517's owner).
    public static var resetMinimum: CGFloat { KiwiShelf().minimum }
}
