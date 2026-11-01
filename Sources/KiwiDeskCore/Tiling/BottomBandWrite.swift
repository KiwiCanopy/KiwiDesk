import ApplicationServices
import CoreGraphics

/// A height shrink near a screen's bottom edge, written from clear
/// of that edge (#2894). macOS refuses a small height shrink of a
/// window ending within ~19 pt of its screen's bottom while the
/// app's `AXEnhancedUserInterface` is off, as KiwiDesk holds it
/// while writing, and another screen reaches lower (macOS 27,
/// Firefox and Finder, measured 2026-11-01). AX frames: y grows
/// down.
enum BottomBandWrite {
    /// How far above a screen's bottom edge a shrink is refused:
    /// measured ~19 pt, escaped from ~25 pt, set wider so a band
    /// that differs by setup still clears.
    static let band: CGFloat = 32

    /// The whole frame of the screen whose bottom edge `frame`
    /// ends near, or nil.
    static func screen(
        for frame: CGRect,
        among screens: [CGRect]
    ) -> CGRect? {
        screens.first { screen in
            frame.midX >= screen.minX && frame.midX < screen.maxX
                && frame.maxY > screen.maxY - band
                && frame.maxY <= screen.maxY + band
        }
    }

    /// Where to move the window before its size is written, with
    /// its `current` frame clear of the band and on `screen`; nil
    /// where the size write would not be refused or no lift clears
    /// it. A size write lands from the window's current top, so it
    /// is refused only when that write ends in the band — a later
    /// frame of a long shrink, never its first — or when the window
    /// arrives from another screen. The lift keeps the current
    /// width on `screen`: a window hanging over onto a neighbouring
    /// screen takes no size write at all.
    static func liftedOrigin(
        target: CGRect,
        current: CGRect,
        screen: CGRect
    ) -> CGPoint? {
        let arriving = !screen.contains(
            CGPoint(x: current.midX, y: current.midY)
        )
        let edge = screen.maxY - band
        let refused =
            current.maxY > edge && current.minY + target.height > edge
        guard target.height < current.height, arriving || refused
        else { return nil }
        let clear = edge - current.height
        guard clear >= screen.minY else { return nil }
        let x = max(screen.minX, min(target.minX, screen.maxX - current.width))
        return CGPoint(x: x, y: min(clear, target.minY))
    }

    /// The band a write merged over a waiting one carries: the
    /// newer frame's, else the waiting one's where the newer frame
    /// still ends in it, since the waiting write never ran.
    static func mergedBand(
        newer: CGRect?,
        waiting: CGRect?,
        frame: CGRect
    ) -> CGRect? {
        newer ?? waiting.flatMap { screen(for: frame, among: [$0]) }
    }

    /// Writes `frame` through `writer`, lifted first where the
    /// band of `screen` would refuse its size; runs on the app's
    /// frame queue. A nil `screen` is the plain write.
    static func write(
        _ frame: CGRect,
        _ element: AXUIElement,
        nearBottomOf screen: CGRect?,
        writer: FrameWriter
    ) {
        if let screen,
            let current = writer.frame(element),
            let origin = liftedOrigin(
                target: frame,
                current: current,
                screen: screen
            )
        {
            writer.setPosition(origin, element)
        }
        writer.setFrame(frame, element)
    }
}
