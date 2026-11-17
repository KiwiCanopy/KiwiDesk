import AppKit

/// A section that comes on screen under a resting pointer opens and
/// swaps in no peek until the pointer moves (#3388): the pointer
/// asked for nothing, and a peek opened from the placement's hover
/// re-read was seen standing on the device until the pointer crossed
/// its item. A reading still closes a peek, and the first reading
/// after the pointer moves opens one as ever.
extension BarPeek {
    /// A section `ShelfOverlay.show` brought on screen, and the
    /// pointer's resting point in its window then.
    struct Arrival {
        weak var root: NSView?
        let window: NSWindow
        let point: CGPoint
    }

    /// Marks `roots` arrived under the pointer where it rests now.
    func arrive(_ roots: [NSView]) {
        arrivals.removeAll { mark in
            mark.root == nil || roots.contains { $0 === mark.root }
        }
        for root in roots {
            guard let window = root.window else { continue }
            arrivals.append(
                Arrival(
                    root: root,
                    window: window,
                    point: BarHoverHit.restingPoint(in: window)
                )
            )
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
        if BarHoverHit.restingPoint(in: mark.window) == mark.point {
            return true
        }
        arrivals.remove(at: index)
        return false
    }
}
