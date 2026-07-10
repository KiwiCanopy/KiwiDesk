import AppKit
import CoreGraphics

/// Coordinate conversion helpers.
///
/// The Accessibility API uses a TOP-left origin (y grows down
/// from the top of the primary display); Cocoa/NSScreen uses a
/// BOTTOM-left origin. KiwiDesk works in AX coordinates
/// everywhere; NSScreen values are flipped at the boundary.
public enum GeometryUtils {
    /// Flips a rect between Cocoa and AX coordinate systems.
    /// The operation is its own inverse.
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

    /// A screen's usable area in AX coordinates. When the
    /// menu bar auto-hides, its reserved strip is reclaimed —
    /// only user-configured gaps remain at the top.
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

    /// True when the macOS menu bar auto-hides on the desktop
    /// (System Settings > Control Center). visibleFrame keeps
    /// the menu bar strip reserved even then; windows may use
    /// it.
    public static var menuBarAutoHides: Bool {
        let domain = UserDefaults.standard.persistentDomain(
            forName: UserDefaults.globalDomain
        )
        return (domain?["_HIHideMenuBar"] as? NSNumber)?
            .boolValue ?? false
    }

    /// Extends a visibleFrame's top edge over the menu bar
    /// strip (Cocoa coordinates). The notch housing (safeTop)
    /// stays reserved: WindowServer clamps regular windows
    /// below it, and fighting that clamp would wobble every
    /// retile.
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
