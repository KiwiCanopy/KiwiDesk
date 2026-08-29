import CoreGraphics

/// The concrete screen edge a bar occupies. Stored directly in
/// bar styles (`app_bar.edge`) — absolute, never derived from a
/// layout's axis, so both bars can sit on any of the four edges
/// regardless of layout (#293). `CaseIterable` feeds the GUI
/// picker and the CodingKeys parity net.
public enum AppBarEdge: String, Sendable, Codable, CaseIterable,
    Equatable
{
    case top, bottom, left, right

    /// True on a horizontal bar (items in a row).
    public var isHorizontal: Bool {
        self == .top || self == .bottom
    }
}

/// Carves the indicator-bar strip out of a layout's usable area
/// so bar and windows never overlap. Shared by every layout that
/// hosts a bar (monocle, scrolling) via `AppBarHosting`.
public enum AppBarGeometry {
    /// The strip the bar occupies, carved from the resolved
    /// `edge` of `usable` (AX coordinates, y grows downward).
    public static func barFrame(
        in usable: CGRect,
        edge: AppBarEdge,
        thickness: CGFloat
    ) -> CGRect {
        switch edge {
        case .top, .bottom:
            let depth = min(thickness, usable.height)
            return CGRect(
                x: usable.minX,
                y: edge == .top
                    ? usable.minY : usable.maxY - depth,
                width: usable.width,
                height: depth
            )
        case .left, .right:
            let depth = min(thickness, usable.width)
            return CGRect(
                x: edge == .left
                    ? usable.minX : usable.maxX - depth,
                y: usable.minY,
                width: depth,
                height: usable.height
            )
        }
    }

    /// How far a float may sit inside a bar before the clamp
    /// acts. Mirrors the engine's frame tolerance (#148): an
    /// app that lands a hair off the exact target (character grids,
    /// min sizes) must not be re-clamped every retile, which would
    /// wobble the window.
    public static let clampTolerance: CGFloat = 2

    /// Nudges `frame` clear of a painted bar `strip` on its
    /// `edge` (AX coordinates, y grows downward). Keeps a
    /// floating window — which layout never clamps — from
    /// sliding under a bar: the original motivator was a TOP
    /// bar covering the title bar (#242), but a bar reserves
    /// its edge for every window kind, the way the Dock
    /// reserves `visibleFrame` (QA 2026-07-19). A no-op once
    /// the frame is within `clampTolerance` of clear; position
    /// only, size unchanged.
    /// `inset` widens the strip by that much before clearing —
    /// the focus ring's own width, so the RING clears the bar
    /// rather than only the window (#1091). The ring is the
    /// window frame outset by `border.width` and paints at
    /// `.normal` while the bars paint at `BarPanel.level`
    /// (`.floating`), so a window pushed flush against a strip
    /// has that outset sliver hidden under it and the ring reads
    /// as cut off.
    ///
    /// Applied whether or not the window is FOCUSED, which is
    /// the point rather than a simplification: an inset that
    /// depended on focus would move the window a few points
    /// every time it gained or lost the ring. Callers pass 0
    /// when rings are off.
    public static func clampClear(
        _ frame: CGRect,
        of strip: CGRect,
        edge: AppBarEdge,
        inset: CGFloat = 0
    ) -> CGRect {
        var result = frame
        switch edge {
        case .top:
            let clear = strip.maxY + inset
            guard frame.minY < clear - clampTolerance
            else { return frame }
            result.origin.y = clear
        case .bottom:
            let clear = strip.minY - inset
            guard frame.maxY > clear + clampTolerance
            else { return frame }
            result.origin.y = clear - frame.height
        case .left:
            let clear = strip.maxX + inset
            guard frame.minX < clear - clampTolerance
            else { return frame }
            result.origin.x = clear
        case .right:
            let clear = strip.minX - inset
            guard frame.maxX > clear + clampTolerance
            else { return frame }
            result.origin.x = clear - frame.width
        }
        return result
    }

    /// `region` with the bar `strip` carved off its own `edge`.
    ///
    /// **Its sibling is `windowFrame(in:minus:edge:inner:)`
    /// below, not `clampClear` above** (architect review,
    /// 2026-08-29). Both carve a region; they differ in who is
    /// asking. `windowFrame` serves the LAYOUT, so it also
    /// spends an inner gap and trusts the strip to sit on the
    /// edge. This serves a FLOAT, which the layout never places:
    /// no gap, the strip clamped rather than trusted, and the
    /// extent floored at zero — a float can sit anywhere, so the
    /// carve cannot assume the strip is where a bar style says
    /// it should be. A new caller takes `windowFrame` if the
    /// layout is placing the window and this if it is not.
    ///
    /// It is NOT `clampClear`'s sibling, which answers "where
    /// may this frame sit" by MOVING it and never resizing it —
    /// which is why a window larger than the space between two
    /// bars was pushed aside and still overflowed (#1091).
    ///
    /// Monotonic, like `clampClear`, so a fold over several
    /// strips composes in any order and two strips on one edge
    /// leave the deeper one's carve standing. Never returns a
    /// negative extent: bars deeper than the screen would
    /// otherwise produce an inside-out rect that reads as
    /// enormous free space.
    /// `inset` carves that much further, for the same reason
    /// `clampClear`'s does: a float GROWN flush to the region's
    /// edge would otherwise have its ring hidden under the bar,
    /// so the two must inset alike or the fix covers only the
    /// windows that were pushed and not the ones that grew.
    public static func regionClear(
        _ region: CGRect,
        of strip: CGRect,
        edge: AppBarEdge,
        inset: CGFloat = 0
    ) -> CGRect {
        var result = region
        let strip = strip.insetBy(dx: -inset, dy: -inset)
        switch edge {
        case .top:
            let cut = max(result.minY, strip.maxY)
            result.size.height = max(0, result.maxY - cut)
            result.origin.y = cut
        case .bottom:
            result.size.height = max(
                0,
                min(result.maxY, strip.minY) - result.minY
            )
        case .left:
            let cut = max(result.minX, strip.maxX)
            result.size.width = max(0, result.maxX - cut)
            result.origin.x = cut
        case .right:
            result.size.width = max(
                0,
                min(result.maxX, strip.minX) - result.minX
            )
        }
        return result
    }

    /// `usable` minus the bar `strip` and one inner gap between
    /// strip and window.
    public static func windowFrame(
        in usable: CGRect,
        minus strip: CGRect,
        edge: AppBarEdge,
        inner: Gaps.Inner
    ) -> CGRect {
        var frame = usable
        switch edge {
        case .top:
            let cut = strip.height + inner.vertical
            frame.origin.y += cut
            frame.size.height = max(usable.height - cut, 0)
        case .bottom:
            let cut = strip.height + inner.vertical
            frame.size.height = max(usable.height - cut, 0)
        case .left:
            let cut = strip.width + inner.horizontal
            frame.origin.x += cut
            frame.size.width = max(usable.width - cut, 0)
        case .right:
            let cut = strip.width + inner.horizontal
            frame.size.width = max(usable.width - cut, 0)
        }
        return frame
    }
}

/// A layout that can show the indicator bar: it owns a
/// per-layout `LayoutAppBar` (whose `edge` override, like every
/// look field, falls back to the global style).
public protocol AppBarHosting {
    var appBar: LayoutAppBar { get }
}

extension AppBarHosting {
    /// The concrete style this layout's bar renders with: the
    /// global `style` overlaid by this layout's overrides. Its
    /// `edge` is the stored absolute one — the single source
    /// everything downstream reads. Resolve once, here, at the
    /// layer boundary.
    public func resolvedBar(
        global: AppBarStyle
    ) -> AppBarStyle {
        appBar.resolved(with: global)
    }

    /// The strip the bar occupies, or nil while it is off.
    public func barFrame(
        in usable: CGRect,
        global: AppBarStyle
    ) -> CGRect? {
        guard appBar.enabled else { return nil }
        let style = resolvedBar(global: global)
        return AppBarGeometry.barFrame(
            in: usable,
            edge: style.edge,
            thickness: style.thickness
        )
    }

    /// The window area: `usable` minus the bar strip and one
    /// inner gap. Falls back to all of `usable` when off.
    public func windowFrame(
        in usable: CGRect,
        inner: Gaps.Inner,
        global: AppBarStyle
    ) -> CGRect {
        guard let strip = barFrame(in: usable, global: global)
        else { return usable }
        return AppBarGeometry.windowFrame(
            in: usable,
            minus: strip,
            edge: resolvedBar(global: global).edge,
            inner: inner
        )
    }
}
