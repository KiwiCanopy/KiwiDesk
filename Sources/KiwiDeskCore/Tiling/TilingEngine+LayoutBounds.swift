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
        let area = spaceArea(space.id)
        return settings.layoutBounds(
            from: visibleBounds(screen, for: space.id),
            mode: space.mode,
            on: area?.key ?? fingerprint(of: screen),
            pocketAtRest: settings.pocketRests
        )
    }

    /// The visible frame `space` lays out in on `screen`: the
    /// screen's own where it is not split, else its area's rect
    /// intersected with it, so the menu bar, notch and Dock insets
    /// land on the area that touches them (#3517 ruling 8). The
    /// screen's size still enters through `visibleBounds` alone.
    func visibleBounds(_ screen: NSScreen, for space: SpaceID) -> CGRect {
        let visible = visibleBounds(screen)
        guard let area = spaceArea(space) else { return visible }
        let clipped = visible.intersection(areaFrame(area.rect, on: screen))
        return clipped.isNull ? visible : clipped
    }

    /// An area's rect, in its screen's own points, in AX coordinates.
    func areaFrame(_ rect: CGRect, on screen: NSScreen) -> CGRect {
        let whole = screenFrameAX(screen)
        return rect.offsetBy(dx: whole.minX, dy: whole.minY)
    }
}
