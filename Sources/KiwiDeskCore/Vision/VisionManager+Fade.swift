import QuartzCore

/// The leave fade (#2417): the window focus left eases into the
/// dim and the blur while the new focus, above the plate, clears at
/// once — so the plate never orders above it and the fade adds no
/// WindowServer round trip.
extension VisionManager {
    /// The window focus left and how it fades.
    struct Leaving: Equatable {
        /// The window, AppKit global frame; its `clear` is unread.
        var window: VisionMask.Window
        var duration: CFTimeInterval
        var curve: VisionFadeCurve
    }

    /// Starts `leaving`'s fade on `plate` where the window lies on
    /// `screen`, then commits it: the order that puts the window
    /// under the plate must not reach WindowServer ahead of the
    /// mask, or the window is covered whole for a frame.
    func fadeLeaving(
        _ leaving: Leaving?,
        on plate: any VisionPlateBackend,
        screen: CGRect
    ) {
        guard let leaving, leaving.duration > 0,
            leaving.window.frame.intersects(screen)
        else { return }
        plate.fadeIn(
            VisionMask.shape(of: leaving.window, on: screen),
            duration: leaving.duration,
            curve: leaving.curve
        )
        CATransaction.flush()
    }
}
