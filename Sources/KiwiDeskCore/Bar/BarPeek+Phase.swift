import AppKit

/// The peek's state (#1946): the anchor it stands at and the one
/// phase it is in.
extension BarPeek {
    /// An item the peek stands at: what it shows, where it stood.
    struct Anchor {
        weak var view: NSView?
        let source: BarPeekSource
        /// The Space Bar chip's Space; nil on the App Bar.
        let space: SpaceID?
        let edge: AppBarEdge
        var frame: CGRect?
    }

    /// Where the peek stands: closed, resting out its dwell on an
    /// anchor, or showing one — `holding` while the pointer has left
    /// the item for its hull (`BarPeekHull`). Written only in
    /// `BarPeek.swift`, behind its methods.
    enum Phase {
        case idle
        case dwelling(Anchor)
        case showing(Anchor, holding: Bool)
    }

    var shown: Anchor? {
        guard case .showing(let anchor, _) = phase else { return nil }
        return anchor
    }
    var pending: Anchor? {
        guard case .dwelling(let anchor) = phase else { return nil }
        return anchor
    }
    var holding: Bool {
        guard case .showing(_, true) = phase else { return false }
        return true
    }
}
