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

    /// `frame` pushed down clear of a painted TOP strip (#242),
    /// position only, size unchanged — the one bar correction a
    /// float takes (#3163). `inset` widens the strip by the focus
    /// ring's reach so the RING clears the bar too (#1091), applied
    /// whether or not the window is FOCUSED: a focus-dependent
    /// inset would move the window on every ring change.
    public static func pushedBelow(
        _ frame: CGRect,
        strip: CGRect,
        inset: CGFloat = 0
    ) -> CGRect {
        let clear = strip.maxY + inset
        guard frame.minY < clear - clampTolerance else { return frame }
        var result = frame
        result.origin.y = clear
        return result
    }

    /// Carves `strip` from `region` for float bounding (#1091).
    /// Monotonic, and never a negative extent — an inside-out
    /// rect reads as enormous free space.
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

/// Protocol for layouts supporting an indicator bar. The bar
/// sits on the KiwiShelf, which reserves its room in every
/// layout
/// (`TilingSettings.layoutBounds(from:mode:on:pocketAtRest:)`,
/// #1517), so a hosting layout places its windows exactly as any
/// other does.
public protocol AppBarHosting {
    var appBar: LayoutAppBar { get }
}

extension AppBarHosting {
    /// Resolves layout bar overrides against global style.
    public func resolvedBar(
        global: AppBarLook
    ) -> AppBarLook {
        appBar.look(on: global)
    }
}
