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

        /// The one target the pointer can open (#3349), Cocoa: the
        /// approach along `run` from `outward` past `side` — the
        /// screen side of the shelf's area, on the edge's axis — to
        /// `inward` in, cut at a run's end where a sibling's approach
        /// meets it; a push where `side` is the screen's edge and no
        /// screen continues past it (`beyond`), so a pointer crossing
        /// to a neighbour opens nothing. `strip` defaults to `run`.
        static func along(
            _ run: CGRect,
            edge: AppBarEdge,
            side: CGFloat? = nil,
            strip: CGRect? = nil,
            screen: CGRect,
            beyond: Bool = false,
            handle: CGRect? = nil,
            section: CGRect? = nil,
            outward: CGFloat = ShelfReveal.overshoot,
            inward: CGFloat = ShelfReveal.approachReach,
            cut: (lead: Bool, trail: Bool) = (false, false)
        ) -> Target {
            let side =
                side
                ?? {
                    switch edge {
                    case .top: run.maxY
                    case .bottom: run.minY
                    case .left: run.minX
                    case .right: run.maxX
                    }
                }()
            var approach = ShelfReveal.approach(
                along: run,
                edge: edge,
                side: side,
                outward: outward,
                inward: inward
            )
            // Cocoa runs bottom to top along a side edge, AX top to
            // bottom: there the leading end is the top.
            let reach = ShelfReveal.alongReach
            let low = edge.isHorizontal ? cut.lead : cut.trail
            let high = edge.isHorizontal ? cut.trail : cut.lead
            let cuts = CGFloat((low ? 1 : 0) + (high ? 1 : 0)) * reach
            let shift = low ? reach : 0
            if edge.isHorizontal {
                approach.origin.x += shift
                approach.size.width -= cuts
            } else {
                approach.origin.y += shift
                approach.size.height -= cuts
            }
            let screenSide: CGFloat =
                switch edge {
                case .top: screen.maxY
                case .bottom: screen.minY
                case .left: screen.minX
                case .right: screen.maxX
                }
            return Target(
                edge: edge,
                strip: strip ?? run,
                screen: screen,
                approach: approach,
                handle: handle,
                flush: !beyond
                    && abs(screenSide - side) <= ShelfReveal.pushReach,
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
