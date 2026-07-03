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

    /// A screen's usable area in AX coordinates.
    @MainActor
    public static func axVisibleFrame(
        of screen: NSScreen
    ) -> CGRect {
        flip(
            screen.visibleFrame,
            primaryHeight: primaryHeight
        )
    }
}
