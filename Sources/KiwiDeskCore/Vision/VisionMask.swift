import CoreGraphics

/// The shape a KiwiVision plate draws (#2103 ruling 21). Pure and
/// actor-free; the plate masks its content with the path, which
/// clips the dim and the blur alike (v2 probe P8).
public enum VisionMask {
    /// One window below the plate.
    public struct Window: Equatable, Sendable {
        /// AppKit global frame.
        public var frame: CGRect
        /// The window's own corner radius.
        public var cornerRadius: CGFloat
        /// Whether it stays clear: its visible part is a hole.
        public var clear: Bool

        public init(frame: CGRect, cornerRadius: CGFloat, clear: Bool) {
            self.frame = frame
            self.cornerRadius = cornerRadius
            self.clear = clear
        }
    }

    /// What the plate on `screen` draws, in the plate's own
    /// coordinates (origin at the screen's bottom-left); nil for
    /// the whole screen. `windows` run FRONT to back: each one's
    /// visible part — its shape less every window in front — is
    /// hazed or left as a hole, and the wallpaper, what no window
    /// covers, is hazed unless `clearWallpaper`.
    public static func path(
        screen: CGRect,
        clearWallpaper: Bool,
        windows: [Window]
    ) -> CGPath? {
        guard clearWallpaper || windows.contains(where: \.clear) else {
            return nil
        }
        var drawn = CGPath(rect: .zero, transform: nil)
        var covered = CGPath(rect: .zero, transform: nil)
        for window in windows {
            guard window.frame.intersects(screen) else { continue }
            let rect = window.frame.offsetBy(
                dx: -screen.minX,
                dy: -screen.minY
            )
            let radius = min(
                window.cornerRadius,
                rect.width / 2,
                rect.height / 2
            )
            let shape = CGPath(
                roundedRect: rect,
                cornerWidth: radius,
                cornerHeight: radius,
                transform: nil
            )
            if !window.clear {
                drawn = drawn.union(shape.subtracting(covered))
            }
            covered = covered.union(shape)
        }
        if !clearWallpaper {
            let whole = CGPath(
                rect: CGRect(origin: .zero, size: screen.size),
                transform: nil
            )
            drawn = drawn.union(whole.subtracting(covered))
        }
        return drawn
    }
}
