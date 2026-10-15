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
        let holes = windows.contains(where: \.clear)
        guard clearWallpaper || holes else { return nil }
        // Nothing clear: every window draws whole, and the non-zero
        // fill unions them with no boolean operation per pass.
        guard holes else {
            let union = CGMutablePath()
            for window in windows where window.frame.intersects(screen) {
                let (rect, radius) = local(window, on: screen)
                union.addRoundedRect(
                    in: rect,
                    cornerWidth: radius,
                    cornerHeight: radius
                )
            }
            return union
        }
        var drawn = CGPath(rect: .zero, transform: nil)
        var covered = CGPath(rect: .zero, transform: nil)
        for window in windows {
            guard window.frame.intersects(screen) else { continue }
            let (rect, radius) = local(window, on: screen)
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

    /// `window`'s frame in the plate's coordinates, and the radius
    /// that frame can take.
    private static func local(
        _ window: Window,
        on screen: CGRect
    ) -> (CGRect, CGFloat) {
        let rect = window.frame.offsetBy(dx: -screen.minX, dy: -screen.minY)
        return (
            rect,
            min(window.cornerRadius, rect.width / 2, rect.height / 2)
        )
    }
}
