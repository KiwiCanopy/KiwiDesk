import ApplicationServices
import CoreGraphics

/// A height shrink of a window resting near its screen's bottom
/// edge, written from clear of that edge (#2894).
///
/// macOS refuses a small height shrink of a window whose bottom
/// edge lies within ~19 pt of its screen's bottom when the app's
/// `AXEnhancedUserInterface` is off — as KiwiDesk holds it while
/// writing — and another screen reaches lower than that edge
/// (macOS 27, Firefox and Finder, measured 2026-11-01). A spring's
/// last frames are such shrinks, so the window kept an earlier
/// frame and the #677 learner confirmed a false bound. A write
/// whose target ends near a screen's bottom therefore moves the
/// window up until its CURRENT bottom clears the band, then
/// writes the frame. AX frames throughout: y grows down.
enum BottomBandWrite {
    /// How far above a screen's bottom edge a size write is
    /// refused: measured ~19 pt, escaped from ~25 pt, set wider so
    /// a band that differs by setup still clears.
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
    /// `current` height clear of the band; nil where the write is
    /// no height shrink. Never above the screen's top, where a
    /// window as tall as the screen stays as refused as before.
    static func liftedY(
        target: CGRect,
        current: CGSize,
        screen: CGRect
    ) -> CGFloat? {
        guard target.height < current.height else { return nil }
        let clear = screen.maxY - band - current.height
        return max(min(clear, target.minY), screen.minY)
    }

    /// Writes `frame` through `writer`, lifted first where the
    /// band would refuse its size; runs on the app's frame queue.
    static func write(
        _ frame: CGRect,
        _ element: AXUIElement,
        screens: [CGRect],
        writer: FrameWriter
    ) {
        if let screen = screen(for: frame, among: screens),
            let current = writer.size(element),
            let y = liftedY(target: frame, current: current, screen: screen)
        {
            writer.setPosition(CGPoint(x: frame.minX, y: y), element)
        }
        writer.setFrame(frame, element)
    }
}
