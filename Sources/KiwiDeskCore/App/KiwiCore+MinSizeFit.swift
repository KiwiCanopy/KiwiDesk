import AppKit
import CoreGraphics

/// How many windows of a minimum size fit side by side and
/// stacked on one screen (#3461): a readout, never stored.
public struct MinSizeFit: Equatable, Sendable {
    /// The screen's own name, for the GUI to quote.
    public var screen: String
    public var across: Int
    public var down: Int

    public init(screen: String, across: Int, down: Int) {
        self.screen = screen
        self.across = across
        self.down = down
    }

    /// Windows of `size` that fit in `region` with `gaps` between
    /// them and around them: each axis's length less its outer
    /// gaps, plus one inner gap, over one window and one gap.
    public static func counts(
        of size: MinSize,
        in region: CGSize,
        gaps: Gaps
    ) -> (across: Int, down: Int) {
        func fit(_ span: CGFloat, _ side: CGFloat, _ gap: CGFloat) -> Int {
            guard side + gap > 0 else { return 0 }
            return max(0, Int(((span + gap) / (side + gap)).rounded(.down)))
        }
        let width = region.width - gaps.outer.left - gaps.outer.right
        let height = region.height - gaps.outer.top - gaps.outer.bottom
        return (
            fit(width, size.width, gaps.inner.horizontal),
            fit(height, size.height, gaps.inner.vertical)
        )
    }
}

extension KiwiCore {
    /// What `size` fits on the main screen — the one with the
    /// menu bar, whose size the starter seeds from — under
    /// `settings`, the Settings DRAFT, in `layout`'s region; nil
    /// with no screen.
    /// The region is the one the layout fills, with the draft's
    /// own strip reserved over the one bounds hook (#531), as the
    /// scrolling column cap does, and the global gaps.
    @MainActor
    public func minSizeFit(
        _ size: MinSize,
        in layout: MinWindowSizes.Layout,
        settings: TilingSettings
    ) -> MinSizeFit? {
        guard let screen = ScreenList.all.first else { return nil }
        let region = settings.layoutBounds(
            from: tiler.visibleBounds(screen),
            mode: layout.mode,
            on: tiler.fingerprint(of: screen, in: settings),
            pocketAtRest: settings.pocketRests
        )
        let counts = MinSizeFit.counts(
            of: size,
            in: region.size,
            gaps: settings.gapsGlobal
        )
        return MinSizeFit(
            screen: screen.localizedName,
            across: counts.across,
            down: counts.down
        )
    }
}
