import AppKit

extension ShelfRevealer {
    /// A hiding bar as `updateBars()` last laid it, in Cocoa
    /// coordinates (y grows up): its shelf's strip and its screen's
    /// frame.
    struct Target: Equatable {
        let edge: AppBarEdge
        let strip: CGRect
        let screen: CGRect
        /// Where resting opens the bar (`ShelfReveal.band`); nil for
        /// a `hidden` bar, which only its shortcut shows.
        var band: CGRect?
        /// Where the pointer lights the mark's hover cue: around
        /// the mark, and the band.
        var near: CGRect?

        init(
            edge: AppBarEdge,
            strip: CGRect,
            screen: CGRect,
            band: CGRect?,
            near: CGRect? = nil
        ) {
            self.edge = edge
            self.strip = strip
            self.screen = screen
            self.band = band
            self.near = band.map { (near ?? $0).union($0) }
        }

        /// A target the pointer can open: the band and its cue.
        static func hovering(
            edge: AppBarEdge,
            strip: CGRect,
            screen: CGRect,
            band: CGRect? = nil,
            near: CGRect? = nil
        ) -> Target {
            Target(
                edge: edge,
                strip: strip,
                screen: screen,
                band: band ?? ShelfReveal.band(of: strip, edge: edge),
                near: near
            )
        }

        /// Whether the pointer can open it.
        var hovers: Bool { band != nil }

        /// Where the pointer holds a shown bar: the strip and its
        /// band, out to the push reach, so a pointer resting on the
        /// screen's last row is inside (`CGRect` excludes `maxY`).
        var zone: CGRect {
            strip.union(band ?? strip).insetBy(
                dx: -ShelfReveal.pushReach,
                dy: -ShelfReveal.pushReach
            )
        }
    }
}
