import CoreGraphics

/// The shape a KiwiVision plate draws (#2103 ruling 21): the whole
/// screen, or — with the wallpaper kept clear — only the windows
/// below the plate, each a rounded rect at the window corner
/// radius. Pure and actor-free; the plate masks its content with
/// the path, which clips the dim and the blur alike (v2 probe P8).
public enum VisionMask {
    /// What the plate on `screen` draws, in the plate's own
    /// coordinates (origin at the screen's bottom-left, AppKit's
    /// orientation); nil for the whole screen. `windows` are AppKit
    /// global frames; a window off this screen draws nothing here.
    public static func path(
        screen: CGRect,
        clearWallpaper: Bool,
        windows: [CGRect],
        cornerRadius: CGFloat
    ) -> CGPath? {
        guard clearWallpaper else { return nil }
        let path = CGMutablePath()
        for frame in windows {
            let local = frame.intersection(screen)
            guard !local.isNull, local.width > 0, local.height > 0
            else { continue }
            let rect = frame.offsetBy(dx: -screen.minX, dy: -screen.minY)
            let radius = min(cornerRadius, rect.width / 2, rect.height / 2)
            // One winding for every window: the non-zero fill unions
            // overlapping windows rather than cutting their overlap.
            path.addRoundedRect(
                in: rect,
                cornerWidth: radius,
                cornerHeight: radius
            )
        }
        return path
    }
}
