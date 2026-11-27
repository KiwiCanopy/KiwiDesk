import AppKit
import CoreGraphics

/// The layout region per screen, split from
/// `TilingEngine+Layout.swift` for the file ceiling.
extension TilingEngine {
    /// The layout region on `screen`: its visible bounds with the
    /// Space Bar's strip already reserved (#293). Every consumer
    /// of a layout *span* reads it here — the layouts themselves,
    /// track capacity, and the resize paths in `Commands/` and
    /// `Tiling/` (#537), which measured their delta against the
    /// whole display and so understated every ratio nudge by the
    /// strip and stored the scrolling slot's points against the
    /// wrong length. `LayoutBoundsRoutingTests` fails on a raw
    /// `visibleBounds` consumer outside its allowlist.
    ///
    /// Not a *second* bounds hook: the display size still enters
    /// through `visibleBounds` alone (#531). This only reserves
    /// the strip on top of it — the strips of the edges the bars
    /// take on THIS screen (#1948).
    ///
    /// It is the region **before outer gaps**, while the layouts
    /// divide `area` = region minus those gaps
    /// (`LayoutSystem`). That is deliberate for a cap's
    /// `available:` — a superset must never block reaching the
    /// visible bound — but it does leave a `delta / span`
    /// division, and the scrolling seed, off by the outer gap.
    /// Much smaller than the strip this fixed, and not a
    /// licence to assume the seam is exact.
    func layoutBounds(on screen: NSScreen, for space: Space) -> CGRect {
        let input = shelfInput(for: space.id, on: screen)
        return settings.layoutBounds(
            from: visibleBounds(screen, for: space.id),
            mode: space.mode,
            on: input.key,
            pocketAtRest: input.pocketAtRest
        )
    }

    /// The key `space`'s shelf reservation resolves under on
    /// `screen` — its area's where the screen is split, else the
    /// screen's — and whether the Pocket rests there: in a split
    /// screen's lead area alone, where the shelf draws it (#3517,
    /// bars.md). Every carve of a Space's bounds takes it.
    func shelfInput(
        for space: SpaceID,
        on screen: NSScreen
    ) -> (key: String?, pocketAtRest: Bool) {
        let area = spaceArea(space)
        return (
            area.map(\.key) ?? barKey(of: screen),
            settings.pocketRests && (area?.lead ?? true)
        )
    }

    /// The visible frame `space` lays out in on `screen`: the
    /// screen's own where it is not split, else its area's rect
    /// intersected with it, so the menu bar, notch and Dock insets
    /// land on the area that touches them (#3517 ruling 8). The
    /// screen's size still enters through `visibleBounds` alone.
    func visibleBounds(_ screen: NSScreen, for space: SpaceID) -> CGRect {
        guard let area = spaceArea(space) else {
            return visibleBounds(screen)
        }
        return areaFrame(area.rect, on: screen)
    }

    /// An area's rect, given in its screen's own points, as AX
    /// coordinates clipped to the screen's visible frame — the one
    /// clip every area reader takes (#3517): layout, the neighbour
    /// scan, the screen hop and the arrival area.
    func areaFrame(_ rect: CGRect, on screen: NSScreen) -> CGRect {
        let visible = visibleBounds(screen)
        let whole = screenFrameAX(screen)
        let clipped = visible.intersection(
            rect.offsetBy(dx: whole.minX, dy: whole.minY)
        )
        return clipped.isNull ? visible : clipped
    }
}
