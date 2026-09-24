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
    /// The strip the bar occupies in AX coordinates, `outer`
    /// points in from its edge (#1516) — every caller chooses,
    /// the floor being the style's (`KiwiShelf.minMargin`).
    public static func barFrame(
        in bounds: CGRect,
        edge: AppBarEdge,
        thickness: CGFloat,
        outer: CGFloat
    ) -> CGRect {
        switch edge {
        case .top, .bottom:
            let depth = max(0, min(thickness, bounds.height - outer))
            return CGRect(
                x: bounds.minX,
                y: edge == .top
                    ? bounds.minY + outer
                    : bounds.maxY - outer - depth,
                width: bounds.width,
                height: depth
            )
        case .left, .right:
            let depth = max(0, min(thickness, bounds.width - outer))
            return CGRect(
                x: edge == .left
                    ? bounds.minX + outer
                    : bounds.maxX - outer - depth,
                y: bounds.minY,
                width: depth,
                height: bounds.height
            )
        }
    }

    /// `bounds` with `cut` points carved off `edge` — the one
    /// carve both bars' reservations take (#1516). Never a
    /// negative extent.
    public static func remaining(
        _ bounds: CGRect,
        edge: AppBarEdge,
        reserving cut: CGFloat
    ) -> CGRect {
        var frame = bounds
        switch edge {
        case .top:
            frame.origin.y += cut
            frame.size.height = max(bounds.height - cut, 0)
        case .bottom:
            frame.size.height = max(bounds.height - cut, 0)
        case .left:
            frame.origin.x += cut
            frame.size.width = max(bounds.width - cut, 0)
        case .right:
            frame.size.width = max(bounds.width - cut, 0)
        }
        return frame
    }

    /// Tolerance for bar frame clamping (2 pt, #148).
    public static let clampTolerance: CGFloat = 2

    /// Nudges `frame` clear of a painted bar strip (#242, QA
    /// 2026-07-19); position only, size unchanged. `inset` widens
    /// the strip by the focus ring's width so the RING clears the
    /// bar too (#1091) — applied whether or not the window is
    /// FOCUSED, which is the point: a focus-dependent inset would
    /// move the window on every ring change.
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

    /// Carves `strip` from `region` for float bounding (#1091).
    /// Its sibling is `AppBarHosting.windowFrame(in:outer:global:)`
    /// over `remaining(_:edge:reserving:)`, NOT `clampClear`
    /// (architect review 2026-08-29): a new caller takes
    /// `windowFrame` if the layout is placing the window and this
    /// if it is not — the monocle park takes this. Monotonic, and
    /// never a negative extent — an inside-out rect reads as
    /// enormous free space.
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

}

/// Protocol for layouts supporting an indicator bar.
public protocol AppBarHosting {
    var appBar: LayoutAppBar { get }
}

extension AppBarHosting {
    /// Resolves layout bar overrides against global style.
    public func resolvedBar(
        global: AppBarLook
    ) -> AppBarLook {
        AppBarLook(
            shelf: global.shelf,
            bar: appBar.resolved(with: global.bar)
        )
    }

    /// The bar's strip in `bounds` — the layout bounds BEFORE
    /// the windows' outer gap, since the bar's outer margin is
    /// measured from the screen edge (#1516) — or nil when
    /// disabled.
    public func barFrame(
        in bounds: CGRect,
        global: AppBarLook
    ) -> CGRect? {
        guard appBar.enabled else { return nil }
        let style = resolvedBar(global: global)
        return AppBarGeometry.barFrame(
            in: bounds,
            edge: style.edge,
            thickness: style.thickness,
            outer: style.outerMargin
        )
    }

    /// Window area: the same `bounds` `barFrame` takes, less the
    /// windows' outer gap and the bar's reservation — outer
    /// margin, strip and inner margin. Both doors read one rect
    /// so no caller can hand one the other's; the outer gap
    /// stays the windows' own, so the bar's window side is
    /// `innerMargin` PLUS that gap (#1516).
    public func windowFrame(
        in bounds: CGRect,
        outer: Gaps.Outer,
        global: AppBarLook
    ) -> CGRect {
        let usable = LayoutContext.usable(bounds, outer: outer)
        guard appBar.enabled else { return usable }
        let style = resolvedBar(global: global)
        return AppBarGeometry.remaining(
            usable,
            edge: style.edge,
            reserving: style.reservation
        )
    }
}
