import AppKit

extension ShelfOverlay {
    /// One show's whole input, compared to skip a re-lay of an
    /// unchanged shelf (#1901).
    struct Drawn: Equatable {
        let strip: CGRect
        let edge: AppBarEdge
        let shelf: KiwiShelf
        let sheen: CGFloat
        let sections: [Section]
        let divider: ShelfArrangement.Divider?
        /// The panel's Cocoa frame is flipped against it. Review's:
        /// `GeometryUtils.primaryHeight` has no seam a test can move.
        let primaryHeight: CGFloat
        /// Its glass bit repeats `shelf`'s, which arrives already
        /// gated; kept whole so every overlay compares one value.
        let environment: BarDrawEnvironment
    }
}

/// A section is the same when it is the same view in the same
/// place (#1901).
extension ShelfOverlay.Section: Equatable {
    static func == (a: Self, b: Self) -> Bool {
        a.view === b.view && a.slot == b.slot && a.plate == b.plate
            && a.content == b.content
    }
}
