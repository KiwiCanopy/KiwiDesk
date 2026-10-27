import AppKit

/// The ring of a window changing state (#2676) — floating and
/// back, maximizing and back, out of the pocket — fades out while
/// our spring moves the window and back in once it has settled:
/// a slow app's window trails the spring, so a following ring
/// runs ahead of it. A second hold beside the switch's arrival
/// hold (#1959), on the same overlay flag and reveal.
extension BorderManager {
    struct StateChangeHold: Equatable {
        let window: WindowID
        /// When the spring settled; the wait for the window's own
        /// report starts here.
        var settledAt: CFTimeInterval?
        /// Set by the window's first report near its frame.
        var arrived = false
    }

    /// Holds `window`'s ring dormant for its state change,
    /// revealing any ring an earlier change still holds.
    func holdStateChange(of window: WindowID) {
        guard let overlay = overlays[window] else { return }
        if let old = stateChange, old.window != window {
            overlays[old.window]?.reveal(reduceMotion: reduceMotion())
        }
        overlay.holdDormant()
        stateChange = StateChangeHold(window: window)
    }

    /// `window`'s spring has settled: the ring shows once the
    /// window reports near the frame we sent, or after the cap.
    func stateChangeSettled(_ window: WindowID) {
        guard stateChange?.window == window,
            stateChange?.settledAt == nil
        else { return }
        stateChange?.settledAt = arrivalClock()
        checkStateChange()
    }

    /// A report of `window` at `frame` after its spring settled.
    func noteStateChangeReport(_ window: WindowID, frame: CGRect) {
        guard var hold = stateChange, hold.window == window,
            hold.settledAt != nil, !hold.arrived,
            let sent = commandedFrame(window) ?? specs[window]?.frame,
            abs(frame.minX - sent.minX) <= Self.arrivalTolerance,
            abs(frame.minY - sent.minY) <= Self.arrivalTolerance
        else { return }
        hold.arrived = true
        stateChange = hold
        checkStateChange()
    }

    private func checkStateChange() {
        guard let hold = stateChange, let settled = hold.settledAt
        else { return }
        let now = arrivalClock()
        let due = hold.arrived ? now : settled + Self.arrivalCap
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
