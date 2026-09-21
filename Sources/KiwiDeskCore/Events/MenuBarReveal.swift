import CoreGraphics

/// Where an auto-hidden menu bar reveals from (#1532): the top
/// band of the screen the pointer is on, as deep as the bar the
/// reveal draws — the notch's safe area where there is one, the
/// menu bar's own height elsewhere. Pure over the frames handed
/// in; `MouseTracker.pointerInMenuBarStrip` is the live reading.
enum MenuBarReveal {
    /// One screen's frame and band, Cocoa coordinates (origin
    /// bottom-left, `NSScreen.frame`'s).
    struct Screen: Equatable {
        var frame: CGRect
        var band: CGFloat
    }

    static func band(
        safeTop: CGFloat,
        barHeight: CGFloat
    ) -> CGFloat {
        max(safeTop, barHeight)
    }

    /// `pointer` in Cocoa screen coordinates. A pointer resting
    /// ON the top edge reads `y == frame.maxY`, which
    /// `CGRect.contains` excludes — so the screen is found by
    /// span, the top edge inclusive.
    static func pointerInStrip(
        _ pointer: CGPoint,
        screens: [Screen]
    ) -> Bool {
        guard
            let screen = screens.first(where: {
                $0.frame.minX <= pointer.x
                    && pointer.x < $0.frame.maxX
                    && $0.frame.minY <= pointer.y
                    && pointer.y <= $0.frame.maxY
            })
        else { return false }
        return pointer.y >= screen.frame.maxY - screen.band
    }
}
