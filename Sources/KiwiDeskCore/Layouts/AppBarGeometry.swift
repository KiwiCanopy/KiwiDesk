import CoreGraphics

/// A concrete screen edge the bar occupies, resolved from an
/// axis-relative `AppBarStyle.Position` against a layout's own
/// orientation. Geometry and renderers take this — never a raw
/// `start`/`end` — so an unresolved position can't reach them.
public enum AppBarEdge: Sendable, Equatable {
    case top, bottom, left, right

    /// True on a horizontal bar (items in a row).
    public var isHorizontal: Bool {
        self == .top || self == .bottom
    }

    /// Resolves `position` against the layout axis: `start` = top
    /// on a horizontal axis / left on a vertical one, `end` =
    /// bottom / right. The single resolution site.
    public init(
        position: AppBarStyle.Position,
        horizontalAxis: Bool
    ) {
        switch (position, horizontalAxis) {
        case (.start, true): self = .top
        case (.end, true): self = .bottom
        case (.start, false): self = .left
        case (.end, false): self = .right
        }
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
/// per-layout `LayoutAppBar` and knows whether its focus/scroll
/// axis runs horizontally (which edge the bar resolves to).
public protocol AppBarHosting {
    var appBar: LayoutAppBar { get }
    /// True when the layout's axis is horizontal (bar on
    /// top/bottom); false for a vertical axis (bar left/right).
    var barAxisIsHorizontal: Bool { get }
}

extension AppBarHosting {
    /// The concrete style this layout's bar renders with (the
    /// global `style` overlaid by this layout's overrides) plus
    /// the concrete `edge` its axis-relative position resolves
    /// to. Resolve once, here, at the layer boundary.
    public func resolvedBar(
        global: AppBarStyle
    ) -> (style: AppBarStyle, edge: AppBarEdge) {
        let style = appBar.resolved(with: global)
        let edge = AppBarEdge(
            position: style.position,
            horizontalAxis: barAxisIsHorizontal
        )
        return (style, edge)
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
