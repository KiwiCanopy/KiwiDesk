import AppKit

/// A section that comes on screen under a resting pointer opens and
/// swaps in no peek until the pointer moves (#3388): the pointer
/// asked for nothing, and a peek opened from the placement's hover
/// re-read was seen standing on the device until the pointer crossed
/// its item. A reading still closes a peek, and the first reading
/// after the pointer moves opens one as ever.
extension BarPeek {
    /// A section `ShelfOverlay.show` brought on screen, and where
    /// the pointer rested then, in screen points: the shelf's panel
    /// moves with its plate while the pointer rests.
    struct Arrival {
        weak var root: NSView?
        let point: CGPoint
    }

    /// Marks `roots` arrived under the pointer where it rests now.
    func arrive(_ roots: [NSView]) {
        arrivals.removeAll { mark in
            mark.root?.window == nil
                || roots.contains { $0 === mark.root }
        }
        for root in roots {
            guard let point = Self.restingScreenPoint(of: root) else {
                continue
            }
            arrivals.append(Arrival(root: root, point: point))
        }
    }

    /// Whether `anchor` sits in a section the pointer has not moved
    /// over since it arrived; a moved pointer ends the mark.
    func arrives(_ anchor: NSView) -> Bool {
        guard
            let index = arrivals.firstIndex(where: { mark in
                mark.root.map { anchor.isDescendant(of: $0) } == true
            })
        else { return false }
        let mark = arrivals[index]
        if let root = mark.root,
            Self.restingScreenPoint(of: root) == mark.point
        {
            return true
        }
        arrivals.remove(at: index)
        return false
    }

    /// Where the pointer rests, in screen points, read through the
    /// window `view` is drawn in.
    private static func restingScreenPoint(of view: NSView) -> CGPoint? {
        guard let window = view.window else { return nil }
        return window.convertPoint(
            toScreen: BarHoverHit.restingPoint(in: window)
        )
    }
}
