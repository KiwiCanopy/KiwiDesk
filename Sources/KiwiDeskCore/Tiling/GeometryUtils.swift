import AppKit
import CoreGraphics

/// Coordinate conversion helpers between Cocoa bottom-left and AX top-left
/// origins.
public enum GeometryUtils {
    /// The rect in `rects` that `frame` overlaps most, nil when it
    /// overlaps none — the one copy of the rule
    /// `TilingEngine.screen(containing:)` and the traveler
    /// re-home (#1217) share.
    public static func rect(
        mostlyContaining frame: CGRect,
        among rects: [CGRect]
    ) -> CGRect? {
        func overlap(_ rect: CGRect) -> CGFloat {
            let shared = rect.intersection(frame)
            return shared.isNull ? 0 : shared.width * shared.height
        }
        return
            rects
            .filter { overlap($0) > 0 }
            .max { overlap($0) < overlap($1) }
    }

    /// macOS window corner radius constant (`BorderGeometry`,
    /// `TilingSettings.dragCornerRadius`).
    public static let systemWindowCornerRadius: CGFloat = 16

    /// Flips a rect between Cocoa and AX coordinate systems.
    public static func flip(
        _ rect: CGRect,
        primaryHeight: CGFloat
    ) -> CGRect {
        CGRect(
            x: rect.minX,
            y: primaryHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    /// Height of the primary display (Cocoa origin screen).
    @MainActor
    public static var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    /// Flips a screen point between Cocoa and AX coordinates.
    @MainActor
    public static func axPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    /// A screen's usable area in AX coordinates, reclaiming auto-hidden menu
    /// bar.
    @MainActor
    public static func axVisibleFrame(
        of screen: NSScreen
    ) -> CGRect {
        var visible = screen.visibleFrame
        if menuBarAutoHides {
            visible = reclaimingMenuBar(
                visible,
                screen: screen.frame,
                safeTop: screen.safeAreaInsets.top
            )
        }
        return flip(visible, primaryHeight: primaryHeight)
    }

    /// True when the macOS menu bar is configured to auto-hide.
    public static var menuBarAutoHides: Bool {
        let domain = UserDefaults.standard.persistentDomain(
            forName: UserDefaults.globalDomain
        )
        return (domain?["_HIHideMenuBar"] as? NSNumber)?
            .boolValue ?? false
    }

    /// Extends visibleFrame top edge over menu bar while preserving notch
    /// safeTop.
    static func reclaimingMenuBar(
        _ visible: CGRect,
        screen frame: CGRect,
        safeTop: CGFloat
    ) -> CGRect {
        var result = visible
        let top = frame.maxY - safeTop
        if top > result.maxY {
            result.size.height += top - result.maxY
        }
        return result
    }
}
