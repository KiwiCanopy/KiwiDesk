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
    /// already clear, or a window too tall to clear.
    static func liftedY(
        target: CGRect,
        current: CGRect,
        screen: CGRect
    ) -> CGFloat? {
        guard target.height < current.height,
            current.maxY > screen.maxY - band
        else { return nil }
        let clear = screen.maxY - band - current.height
        guard clear >= screen.minY else { return nil }
        return min(clear, target.minY)
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

/// The height the applier last asked of each window, so only a
/// shrink pays the band's frame read (#2894): a Space switch's
/// unpark asks the size it parked with and reads nothing.
@MainActor
final class AskedHeights {
    private var heights: [WindowID: CGFloat] = [:]

    /// Records `height` as `id`'s ask; true when it is shorter than
    /// the last one, or the first.
    func shrinks(_ id: WindowID, to height: CGFloat) -> Bool {
        defer { heights[id] = height }
        return heights[id].map { height < $0 } ?? true
    }
}

extension FrameApplier {
    /// The screen whose bottom band a sized write must clear: only
    /// a shrink of the height last asked ends refused (#2894).
    func bandScreen(
        _ id: WindowID,
        _ frame: CGRect,
        setSize: Bool
    ) -> CGRect? {
        guard setSize,
            askedHeights.shrinks(id, to: frame.height)
        else { return nil }
        return BottomBandWrite.screen(for: frame, among: screenFrames())
    }
}
