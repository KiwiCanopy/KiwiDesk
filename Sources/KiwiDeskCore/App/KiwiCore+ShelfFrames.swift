import AppKit

extension KiwiCore {
    /// Every KiwiShelf strip the bars last drew on, in AppKit
    /// coordinates — for a panel of the GUI's that must stop short
    /// of the shelf on whatever edge it sits (#2246).
    public func shelfFrames() -> [CGRect] {
        shelves.strips.map {
            GeometryUtils.flip($0, primaryHeight: GeometryUtils.primaryHeight)
        }
    }
}
