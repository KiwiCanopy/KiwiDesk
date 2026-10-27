import AppKit

/// The ring of a window changing state (#2676) — floating and
/// back, maximizing and back, out of the pocket — stays dormant
/// while our spring moves the window and returns once it has
/// landed (`docs/design-decisions.md` ▸ a window changing state).
/// A second hold beside the switch's arrival hold (#1959), on the
/// same overlay flag and reveal.
extension BorderManager {
    struct StateChangeHold: Equatable {
        let window: WindowID
        /// The spring's target, kept from the arm: the commanded
        /// frame an animated write leaves is nil.
        let target: CGRect?
        /// When the hold began; the backstop counts from here.
        let start: CFTimeInterval
        /// When the spring ended; the cap counts from here.
        var settledAt: CFTimeInterval?
        /// Set by the window's first report near its target.
        var arrived = false
    }

    /// The longest a ring stays dormant if no spring end reaches
    /// the hold: past the settle of the longest window duration,
    /// a spring settling in about twice its 1.4× response.
    static let stateChangeBackstop =
        CFTimeInterval(AnimationSettings.durationBand.upperBound)
        / 1000 * 3

    /// Holds `window`'s ring dormant while its spring runs to
    /// `target`, revealing any ring an earlier change still holds.
    func holdStateChange(of window: WindowID, target: CGRect?) {
        guard let overlay = overlays[window] else { return }
        if let old = stateChange, old.window != window {
            overlays[old.window]?.reveal(reduceMotion: reduceMotion())
        }
        overlay.holdDormant()
        stateChange = StateChangeHold(
            window: window,
            target: target,
            start: arrivalClock()
        )
        checkStateChange()
    }

    /// `window`'s spring has ended: the ring shows once the window
    /// reports near its target, or after the cap.
    func stateChangeSettled(_ window: WindowID) {
        guard stateChange?.window == window,
            stateChange?.settledAt == nil
        else { return }
        stateChange?.settledAt = arrivalClock()
        checkStateChange()
    }

    /// A report of `window` at `frame` after its spring ended.
    func noteStateChangeReport(_ window: WindowID, frame: CGRect) {
        guard var hold = stateChange, hold.window == window,
            hold.settledAt != nil, !hold.arrived,
            let sent = hold.target ?? specs[window]?.frame,
            abs(frame.minX - sent.minX) <= Self.arrivalTolerance,
            abs(frame.minY - sent.minY) <= Self.arrivalTolerance
        else { return }
        hold.arrived = true
        stateChange = hold
        checkStateChange()
    }

    private func checkStateChange() {
        guard let hold = stateChange else { return }
        let now = arrivalClock()
        let due =
            hold.settledAt.map {
                hold.arrived ? now : $0 + Self.arrivalCap
            } ?? hold.start + Self.stateChangeBackstop
        guard now >= due else {
            scheduleArrivalCheck(due - now) { [weak self] in
                guard self?.stateChange == hold else { return }
                self?.checkStateChange()
            }
            return
        }
        stateChange = nil
        overlays[hold.window]?.reveal(reduceMotion: reduceMotion())
    }
}
