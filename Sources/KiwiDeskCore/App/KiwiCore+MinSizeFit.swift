import AppKit
import CoreGraphics

/// How many windows of a minimum size fit side by side and
/// stacked on one screen (#3461): a readout, never stored.
public struct MinSizeFit: Equatable, Sendable {
    /// The screen counted on, for the GUI to name.
    public var screen: ScreenLabel
    public var across: Int
    public var down: Int

    public init(screen: ScreenLabel, across: Int, down: Int) {
        self.screen = screen
        self.across = across
        self.down = down
    }

    /// Windows of `size` that fit in `region` with `gaps`: the
    /// region's outer-gap carve (`LayoutContext.usable`) over the
    /// track pitch (`TrackLayout.fitCap`), the engine's own doors.
    public static func counts(
        of size: MinSize,
        in region: CGRect,
        gaps: Gaps
    ) -> (across: Int, down: Int) {
        // `size`, not `width`/`height`: those standardize, so a
        // carve past zero would read as a positive span.
        let usable = LayoutContext.usable(region, outer: gaps.outer).size
        return (
            TrackLayout.fitCap(
                crossSpan: usable.width,
                minSize: size.width,
                gap: gaps.inner.horizontal
            ),
            TrackLayout.fitCap(
                crossSpan: usable.height,
                minSize: size.height,
                gap: gaps.inner.vertical
            )
        )
    }
}

extension KiwiCore {
    /// What each of `sizes` fits on the main screen — the one the
    /// starter seeds from, `PositionalDisplays.liveMainID` — under
    /// `settings`, the Settings DRAFT, each in its layout's region;
    /// empty with no screen. The screen is read once for all of
    /// them; its size comes through the one bounds hook (#531) and
    /// the draft reserves its own strip, as the scrolling column
    /// cap does, with the global gaps.
    @MainActor
    public func minSizeFits(
        _ sizes: [MinWindowSizes.Layout: MinSize],
        settings: TilingSettings
    ) -> [MinWindowSizes.Layout: MinSizeFit] {
        let screens = ScreenList.all
        let main = PositionalDisplays.liveMainID
        guard
            let screen = screens.first(where: {
                $0.kiwiDisplayID == main
            }) ?? screens.first
        else { return [:] }
        // State names a screen once the display resolve has run; a
        // Settings draw ahead of it names the screen as AppKit does.
        let label =
            screen.kiwiDisplayID.flatMap(namedScreenLabel(of:))
            ?? ScreenLabel(name: screen.localizedName)
        let visible = tiler.visibleBounds(screen)
        let fingerprint = tiler.fingerprint(of: screen, in: settings)
        var fits: [MinWindowSizes.Layout: MinSizeFit] = [:]
        for (layout, size) in sizes {
            let region = settings.layoutBounds(
                from: visible,
                mode: layout.mode,
                on: fingerprint,
                pocketAtRest: settings.pocketRests
            )
            let counts = MinSizeFit.counts(
                of: size,
                in: region,
                gaps: settings.gapsGlobal
            )
            fits[layout] = MinSizeFit(
                screen: label,
                across: counts.across,
                down: counts.down
            )
        }
        return fits
    }
}
