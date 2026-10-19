import AppKit

/// KiwiVision's leave fade (#2417): which focus change owes one.
extension KiwiCore {
    /// The window focus left and its fade (#2417): owed only for a
    /// tracked window still on a shown Space, so a Space switch —
    /// which parks it — stays instant (#2228), only while the look's
    /// duration is not 0, and never for the window a lens held,
    /// which was hazed already. The one judge of whether a leave
    /// fade is owed.
    func visionLeaving(
        from old: CGWindowID?,
        to new: CGWindowID?,
        heldBefore: CGWindowID? = nil
    ) -> VisionManager.Leaving? {
        let look = visionLook
        guard vision.isOn, look.fadeDuration > 0, let old, old != new,
            old != heldBefore
        else { return nil }
        let id = WindowID(old)
        let shown = tiler.visiblePlacements(state: state).contains {
            state.effectiveMembers(of: $0.space).contains(id)
        }
        guard shown, let frame = memberFrame(id) else { return nil }
        return VisionManager.Leaving(
            id: old,
            window: VisionMask.Window(
                frame: GeometryUtils.flip(
                    frame,
                    primaryHeight: GeometryUtils.primaryHeight
                ),
                cornerRadius: windowRadius(id, reading: false),
                clear: false
            ),
            duration: Double(look.fadeDuration) / 1000,
            curve: look.fadeCurve
        )
    }
}
