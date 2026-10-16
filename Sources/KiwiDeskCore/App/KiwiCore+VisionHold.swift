import AppKit

/// A lens's delayed clear (#2103 rulings 12, 14, 30, 34): a window
/// the lens leaves out that takes the focus waits under the haze
/// for the lens's delay, a reminder pill centred on it, then
/// clears. The plates order above the held window meanwhile
/// (`VisionManager.Request.holding`); a click on it, a focus
/// elsewhere, the deadline or the lens letting go ends the hold.
extension KiwiCore {
    /// How long a landing waits now, nil while none does: a lens
    /// is on, keeps focus on its apps (ruling 30) and clears after
    /// a delay above 0.
    var visionHoldDelay: Double? {
        guard vision.isOn, let lens = visionLook.lens, lens.keepFocus,
            lens.clearDelay > 0
        else { return nil }
        return lens.clearDelay
    }

    /// The reminder the hold's pill draws: the lens's own text, a
    /// blank one showing the default (ruling 42a).
    var visionReminder: String {
        let own =
            visionLook.lens?.reminder?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard own.isEmpty else { return own }
        return L(
            "kiwivision.reminder.default",
            "🥝 Keep the vision juicy 🥝"
        )
    }

    /// Judges the plates' next target against the hold, ahead of
    /// the sync that draws it: the hold ends where its target left
    /// or the lens stopped asking, and a new target the lens leaves
    /// out begins one. Plates not yet shown — KiwiVision turning
    /// on, a stand-down — make no landing.
    func settleVisionHold(target: CGWindowID?, ownKey: Bool) {
        let previous = vision.target
        let previousClear = vision.hold?.window.raw != previous
        if let hold = vision.hold,
            hold.window.raw != target || visionHoldDelay == nil
        {
            endVisionHold(restack: false)
        }
        guard target != previous, vision.hasShownPlates,
            let target, let delay = visionHoldDelay
        else { return }
        let id = WindowID(target)
        let landing = visionLanding(
            id,
            after: previousClear ? previous : nil,
            ownKey: ownKey
        )
        guard VisionHold.begins(landing) else { return }
        vision.hold = VisionHold(window: id)
        deferred.schedule(.visionHold, after: .seconds(delay)) {
            [weak self] in self?.endVisionHold()
        }
        let reminder = visionReminder
        if let frame = refusalPillFrame(id) {
            borders.showHoldPill(window: id, frame: frame, text: reminder)
        }
        vision.onHold(reminder)
    }

    /// What `id` is as a landing. `clear` is the window that was
    /// clear before it, nil where the plates held it.
    func visionLanding(
        _ id: WindowID,
        after clear: CGWindowID?,
        ownKey: Bool
    ) -> VisionHold.Landing {
        guard let window = state.windows[id], let skip = lensKeySkip()
        else { return VisionHold.Landing(leftOut: false) }
        var landing = VisionHold.Landing(leftOut: skip(id))
        landing.neverDimmed = isNeverDimmed(window.appRef)
        landing.overlay = window.isTransientOverlay || window.isRaisedLayer
        landing.own =
            ownKey || window.carriesOwnMark || window.pid == getpid()
        if let clear, let was = state.windows[WindowID(clear)],
            Self.dialogSubroles.contains(window.subrole ?? "")
        {
            landing.dialogOfClear = eventLoop.names(
                was.pid,
                appOf: window.pid,
                lookingUp: false
            )
        }
        landing.clicked = recentClickReached(id, now: wallClock())
        return landing
    }

    /// The subroles of a dialog a clear window's app opens over it
    /// (ruling 14).
    static let dialogSubroles: Set<String> = [
        "AXDialog", "AXSystemDialog", "AXSheet",
    ]

    /// A left press: one on the held window clears it at once
    /// (ruling 12); typing never does. Resolved from the press
    /// stamp, which names the window the press reached.
    func visionPressed() {
        guard let hold = vision.hold,
            lastLeftClick?.reached == hold.window
        else { return }
        endVisionHold()
    }

    /// Ends the hold: the pill goes, and unless the caller's own
    /// sync follows, the plates re-stack below the window.
    func endVisionHold(restack: Bool = true) {
        guard let hold = vision.hold else { return }
        vision.hold = nil
        deferred.cancel(.visionHold)
        borders.releaseHoldPill(hold.window)
        if restack { updateVision(reassertOrder: true) }
    }
}
