import AppKit
import CoreGraphics

extension KiwiCore {
    /// The most scrolling slots `settings` — the Settings DRAFT,
    /// never the live copy — fits on the screen `space` lays out
    /// on, or with no space (the Layout Defaults card) on the
    /// widest connected one; nil with no screen. The stepper's
    /// ▲ bound (#1382): the screen is chosen here, its size read
    /// through the one bounds hook (#531), and the draft reserves
    /// its own strip on it — the seam's `layoutBounds(on:)` would
    /// reserve the LIVE bar's (`ScrollingColumnCapDoorTests`).
    @MainActor
    public func scrollingColumnCap(
        for space: SpaceID?,
        settings: TilingSettings
    ) -> Int? {
        let screen =
            space.flatMap { TilingEngine.screen(for: $0, in: state) }
            ?? Self.widestScreen(NSScreen.screens)
        guard let screen else { return nil }
        return settings.scrollingColumnCap(
            bounds: settings.layoutBounds(from: tiler.visibleBounds(screen)),
            space: space
        )
    }

    /// The widest of `screens`, ties broken by position so two
    /// equal screens answer the same way every render.
    static func widestScreen(_ screens: [NSScreen]) -> NSScreen? {
        screens.min { lhs, rhs in
            if lhs.frame.width != rhs.frame.width {
                return lhs.frame.width > rhs.frame.width
            }
            if lhs.frame.minX != rhs.frame.minX {
                return lhs.frame.minX < rhs.frame.minX
            }
            return lhs.frame.minY < rhs.frame.minY
        }
    }
}
