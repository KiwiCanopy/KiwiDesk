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

    /// The origin y to write the size from, with the window's
    /// `current` frame clear of the band; nil where nothing would
    /// be refused or no lift clears it: no height shrink, a bottom
    /// already clear on this screen, or a window too tall to clear.
    /// A window arriving from another screen is lifted whatever its
    /// bottom there, since its size lands on this one.
    static func liftedY(
        target: CGRect,
        current: CGRect,
        screen: CGRect
    ) -> CGFloat? {
        let arriving = !screen.contains(
            CGPoint(x: current.midX, y: current.midY)
        )
        guard target.height < current.height,
            arriving || current.maxY > screen.maxY - band
        else { return nil }
        let clear = screen.maxY - band - current.height
        guard clear >= screen.minY else { return nil }
        return min(clear, target.minY)
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
            let y = liftedY(target: frame, current: current, screen: screen)
        {
            writer.setPosition(CGPoint(x: frame.minX, y: y), element)
        }
        writer.setFrame(frame, element)
    }
}
