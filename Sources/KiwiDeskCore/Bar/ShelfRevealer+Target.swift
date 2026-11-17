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
        /// The handle's hover band (`ShelfHandleSpec.hoverBand`),
        /// where resting hurries the fill on to `revealDelay`.
        var handle: CGRect?
        /// The handle rests against the screen's physical edge, so
        /// a push on a free edge opens the bar at once.
        var flush = false
        /// Where the bar draws while shown, nil while it is not —
        /// with the approach, what holds a hover reveal open.
        var section: CGRect?

        /// Through `along` or `hidden` alone, so every approach
        /// takes the one free-edge rule.
        private init(
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

        /// A `hidden` bar's target, which only its shortcut shows: no
        /// approach, held by its section while shown.
        static func hidden(
            edge: AppBarEdge,
            strip: CGRect,
            screen: CGRect,
            section: CGRect? = nil
        ) -> Target {
            Target(
                edge: edge,
                strip: strip,
                screen: screen,
                approach: nil,
                section: section
            )
        }

        /// The one target the pointer can open (#3349), Cocoa: the
        /// approach along `run` from `outward` past `side` — the
        /// screen side of the shelf's area, on the edge's axis — to
        /// `inward` in, cut at a run's end where a sibling's approach
        /// meets it; a push where `side` is the screen's edge and no
        /// screen continues past it (`beyond`), so a pointer crossing
        /// to a neighbour opens nothing. `strip` defaults to `run`;
        /// production takes `side` from
        /// `HidingShelves.side(of:edge:shelf:)`.
        static func along(
            _ run: CGRect,
            edge: AppBarEdge,
            side: CGFloat,
            strip: CGRect? = nil,
            screen: CGRect,
            beyond: Bool = false,
            handle: CGRect? = nil,
            section: CGRect? = nil,
            outward: CGFloat = ShelfReveal.overshoot,
            inward: CGFloat = ShelfReveal.approachReach,
            cut: (lead: Bool, trail: Bool) = (false, false)
        ) -> Target {
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

        /// This target with its approach stopped at `tab`, Cocoa, on
        /// the end facing it: the pocket's tab beside a bar's run,
        /// so a point opens one of them (#3432).
        func yielding(to tab: CGRect) -> Target {
            guard var cut = approach, cut.intersects(tab) else {
                return self
            }
            if edge.isHorizontal {
                let (low, high) = (cut.minX, cut.maxX)
                if tab.midX > cut.midX {
                    cut.size.width = max(0, tab.minX - low)
                } else {
                    cut.origin.x = min(tab.maxX, high)
                    cut.size.width = max(0, high - cut.origin.x)
                }
            } else {
                let (low, high) = (cut.minY, cut.maxY)
                if tab.midY > cut.midY {
                    cut.size.height = max(0, tab.minY - low)
                } else {
                    cut.origin.y = min(tab.maxY, high)
                    cut.size.height = max(0, high - cut.origin.y)
                }
            }
            var out = self
            out.approach = cut
            return out
        }

        /// Where a fill entered at `point` starts (#3360 ▸ 7): the
        /// share of the handle's run, from its AX leading end — the
        /// left, or the top — nearest the point.
        func fillOrigin(at point: CGPoint) -> CGFloat {
            guard let handle, !handle.isEmpty else { return 0.5 }
            let share =
                edge.isHorizontal
                ? (point.x - handle.minX) / handle.width
                : (handle.maxY - point.y) / handle.height
            return min(max(share, 0), 1)
        }

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
