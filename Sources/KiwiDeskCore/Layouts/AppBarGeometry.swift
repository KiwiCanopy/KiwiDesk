import CoreGraphics

/// Carves the indicator-bar strip out of a layout's usable area
/// so bar and windows never overlap. Shared by every layout that
/// hosts a bar (monocle, scrolling) via `AppBarHosting`.
public enum AppBarGeometry {
    /// The strip the bar occupies, carved from the resolved
    /// edge of `usable` (AX coordinates, y grows downward).
    public static func barFrame(
        in usable: CGRect,
        position: AppBarStyle.Position,
        thickness: CGFloat
    ) -> CGRect {
        switch position {
        case .top, .bottom:
            let depth = min(thickness, usable.height)
            return CGRect(
                x: usable.minX,
                y: position == .top
                    ? usable.minY : usable.maxY - depth,
                width: usable.width,
                height: depth
            )
        case .left, .right:
            let depth = min(thickness, usable.width)
            return CGRect(
                x: position == .left
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
        position: AppBarStyle.Position,
        inner: Gaps.Inner
    ) -> CGRect {
        var frame = usable
        switch position {
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
/// axis runs horizontally (which edges the bar may sit on).
public protocol AppBarHosting {
    var appBar: LayoutAppBar { get }
    /// True when the layout's axis is horizontal (bar on
    /// top/bottom); false for a vertical axis (bar left/right).
    var barAxisIsHorizontal: Bool { get }
}

extension AppBarHosting {
    /// The concrete style this layout's bar renders with: the
    /// global `style` overlaid by this layout's overrides, with
    /// `position` clamped to the layout's own axis.
    public func resolvedBar(global: AppBarStyle) -> AppBarStyle {
        var resolved = appBar.resolved(with: global)
        resolved.position = resolved.resolvedPosition(
            horizontalAxis: barAxisIsHorizontal
        )
        return resolved
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
            position: style.position,
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
            position: resolvedBar(global: global).position,
            inner: inner
        )
    }
}
