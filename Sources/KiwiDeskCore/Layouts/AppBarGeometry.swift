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

    /// How far a float's top may sit inside a top bar before the
    /// clamp acts. Mirrors the engine's frame tolerance (#148): an
    /// app that lands a hair off the exact target (character grids,
    /// min sizes) must not be re-clamped every retile, which would
    /// wobble the window.
    public static let clampTolerance: CGFloat = 2

    /// Pushes `frame` down so its top edge sits at or below the
    /// bottom of a TOP bar `strip` (AX coordinates, y grows
    /// downward). Keeps a floating window — which layout never
    /// clamps — from hiding under a top app bar, where the strip
    /// covers the window's title bar (its grab handle) and leaves
    /// it ungrabbable (#242). A no-op once the frame is within
    /// `clampTolerance` of clear; only the top edge is corrected,
    /// size unchanged.
    public static func clampBelowTopStrip(
        _ frame: CGRect,
        strip: CGRect
    ) -> CGRect {
        guard frame.minY < strip.maxY - clampTolerance
        else { return frame }
        var result = frame
        result.origin.y = strip.maxY
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
    /// The concrete style this layout's bar renders with (the
    /// global `style` overlaid by this layout's overrides) plus
    /// its stored absolute `edge`. Resolve once, here, at the
    /// layer boundary.
    public func resolvedBar(
        global: AppBarStyle
    ) -> (style: AppBarStyle, edge: AppBarEdge) {
        let style = appBar.resolved(with: global)
        return (style, style.edge)
    }

    /// The strip the bar occupies, or nil while it is off.
    public func barFrame(
        in usable: CGRect,
        global: AppBarStyle
    ) -> CGRect? {
        guard appBar.enabled else { return nil }
        let (style, edge) = resolvedBar(global: global)
        return AppBarGeometry.barFrame(
            in: usable,
            edge: edge,
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
