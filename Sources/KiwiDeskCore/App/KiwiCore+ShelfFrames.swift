import AppKit

/// A KiwiShelf strip as drawn: its frame in AppKit coordinates and
/// the screen edge it sits on.
public struct ShelfFrame: Equatable, Sendable {
    public let frame: CGRect
    public let edge: AppBarEdge

    public init(frame: CGRect, edge: AppBarEdge) {
        self.frame = frame
        self.edge = edge
    }
}

extension KiwiCore {
    /// Every KiwiShelf strip the bars last drew on, with its edge —
    /// for a panel of the GUI's that must stop short of the shelf
    /// on whatever edge it sits (#2246).
    public func shelfFrames() -> [ShelfFrame] {
        shelves.drawnStrips.map {
            ShelfFrame(
                frame: GeometryUtils.flip(
                    $0.strip,
                    primaryHeight: GeometryUtils.primaryHeight
                ),
                edge: $0.edge
            )
        }
    }
}
