import CoreGraphics

extension ShelfArrangement {
    /// What the section divider's drag moves (#1517, ruling 15),
    /// present only while the shelf is full: the room both
    /// sections share, the Space section's length and the range
    /// `minimumRange` lets it take, and which section leads.
    public struct Divider: Equatable, Sendable {
        public var room: CGFloat
        public var spaceLength: CGFloat
        public var bounds: ClosedRange<CGFloat>
        public var spacesFirst: Bool

        /// The Space Bar minimum, in percent, that puts the
        /// divider `delta` points further along the edge than it
        /// sat when the drag began — the length clamped to what
        /// the shelf lets the Space section take, then to
        /// `KiwiShelf.minimumRange`.
        public func minimum(afterDragging delta: CGFloat) -> CGFloat {
            guard room > 0 else { return KiwiShelf.resetMinimum }
            let signed = spacesFirst ? delta : -delta
            let length = min(
                max(spaceLength + signed, bounds.lowerBound),
                bounds.upperBound
            )
            return min(
                max(length / room * 100, KiwiShelf.minimumRange.lowerBound),
                KiwiShelf.minimumRange.upperBound
            )
        }
    }
}

extension KiwiShelf {
    /// The minimum a double-click on the divider restores.
    public static var resetMinimum: CGFloat { KiwiShelf().minimum }
}
