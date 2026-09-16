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
        let screens = NSScreen.screens
        let own = space.flatMap { TilingEngine.screen(for: $0, in: state) }
        let widest = Self.widest(of: screens.map(\.frame)).map { screens[$0] }
        guard let screen = own ?? widest else { return nil }
        return settings.scrollingColumnCap(
            bounds: settings.layoutBounds(from: tiler.visibleBounds(screen)),
            space: space
        )
    }

    /// The index of the widest of `frames`, ties broken by position
    /// so two equal screens answer the same way every render
    /// (`ScrollingColumnCapDoorTests`).
    static func widest(of frames: [CGRect]) -> Int? {
        frames.indices.min { lhs, rhs in
            let (l, r) = (frames[lhs], frames[rhs])
            if l.width != r.width { return l.width > r.width }
            if l.minX != r.minX { return l.minX < r.minX }
            return l.minY < r.minY
        }
    }
}
