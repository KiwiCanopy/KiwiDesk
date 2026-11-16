import AppKit

extension ShelfRevealer {
    /// A hiding bar as `updateBars()` last laid it, in Cocoa
    /// coordinates (y grows up): its shelf's strip and its screen's
    /// frame.
    struct Target: Equatable {
        let edge: AppBarEdge
        let strip: CGRect
        let screen: CGRect
        /// Where the pointer brings the bar in
        /// (`ShelfReveal.approach`, #3349); nil for a `hidden` bar,
        /// which only its shortcut shows.
        var approach: CGRect?
        /// The thickened handle, where resting `revealDelay` opens
        /// the bar.
        var handle: CGRect?
        /// The handle rests against the screen's physical edge, so
        /// a push on a free edge opens the bar at once.
        var flush = false
        /// Where the bar draws while shown, nil while it is not —
        /// with the approach, what holds a hover reveal open.
        var section: CGRect?

        init(
            edge: AppBarEdge,
            strip: CGRect,
            screen: CGRect,
            approach: CGRect?,
            handle: CGRect? = nil,
            flush: Bool = false,
            section: CGRect? = nil
        ) {
            self.edge = edge
            self.strip = strip
            self.screen = screen
            self.approach = approach
            self.handle = approach == nil ? nil : handle
            self.flush = flush
            self.section = section
        }

        /// A target the pointer can open along the whole `strip`:
        /// the approach from its screen side, and a push where that
        /// side is the screen's.
        static func hovering(
            edge: AppBarEdge,
            strip: CGRect,
            screen: CGRect,
            section: CGRect? = nil
        ) -> Target {
            let side: CGFloat =
                switch edge {
                case .top: strip.maxY
                case .bottom: strip.minY
                case .left: strip.minX
                case .right: strip.maxX
                }
            let edgeOf: CGFloat =
                switch edge {
                case .top: screen.maxY
                case .bottom: screen.minY
                case .left: screen.minX
                case .right: screen.maxX
                }
            return Target(
                edge: edge,
                strip: strip,
                screen: screen,
                approach: ShelfReveal.approach(
                    along: strip,
                    edge: edge,
                    side: side,
                    outward: ShelfReveal.overshoot
                ),
                flush: abs(edgeOf - side) <= ShelfReveal.pushReach,
                section: section
            )
        }

        /// Whether the pointer can open it.
        var hovers: Bool { approach != nil }

        /// The outermost screen row along the approach, where a
        /// push lands (`ShelfReveal.edgeRow`).
        var edgeRow: CGRect? {
            approach.map {
                ShelfReveal.edgeRow(along: $0, edge: edge, screen: screen)
            }
        }

        /// Where the pointer holds a shown bar: the section it
        /// draws and its approach — never the rest of the edge —
        /// out to the push reach, so a pointer resting on the
        /// screen's last row is inside (`CGRect` excludes `maxY`).
        var zone: CGRect {
            let held = [section, approach].compactMap { $0 }
                .reduce(CGRect.null) { $0.union($1) }
            return (held.isNull ? strip : held).insetBy(
                dx: -ShelfReveal.pushReach,
                dy: -ShelfReveal.pushReach
            )
        }
    }
}
