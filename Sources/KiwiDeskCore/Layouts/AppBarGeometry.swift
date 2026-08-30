import CoreGraphics

/// Screen edge a bar occupies (`app_bar.edge`, #293).
public enum AppBarEdge: String, Sendable, Codable, CaseIterable,
    Equatable
{
    case top, bottom, left, right

    /// True on a horizontal bar (items in a row).
    public var isHorizontal: Bool {
        self == .top || self == .bottom
    }
}

/// Computes bar strips and window bounds for layouts hosting a bar.
public enum AppBarGeometry {
    /// The strip the bar occupies in AX coordinates.
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

    /// Tolerance for bar frame clamping (2 pt, #148).
    public static let clampTolerance: CGFloat = 2

    /// Nudges `frame` clear of painted bar `strip` on `edge` (#242, #1091,
    /// QA 2026-07-19).
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

    /// Carves `strip` from `region` for float bounding (#1091, architect
    /// review 2026-08-29).
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

    /// `usable` minus bar `strip` and inner gap.
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

/// Protocol for layouts supporting an indicator bar.
public protocol AppBarHosting {
    var appBar: LayoutAppBar { get }
}

extension AppBarHosting {
    /// Resolves layout bar overrides against global style.
    public func resolvedBar(
        global: AppBarStyle
    ) -> AppBarStyle {
        appBar.resolved(with: global)
    }

    /// Bar strip bounds or nil when disabled.
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

    /// Window area minus bar strip and inner gap.
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
