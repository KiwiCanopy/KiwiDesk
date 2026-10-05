import AppKit

/// The focused ring after a Space switch appears with its window
/// (#1959): kept dormant until the window's own report lands near
/// the frame we sent it, or a cap passes, and never ahead of the
/// slide's plates lifting. Focus moves inside a Space keep the
/// leading ring.
extension BorderManager {
    struct ArrivalHold {
        let window: WindowID
        /// When the hold began.
        let start: CFTimeInterval
        /// The earliest the ring may show — the slide's lift — read
        /// live, since a burst press moves it later.
        let notBefore: @MainActor () -> CFTimeInterval?
        /// The frame the switch sent the window, kept from the
        /// first read: a stale echo retires the commanded frame
        /// before the window gets there.
        var target: CGRect?
        /// Set by the window's first report near its target.
        var arrived = false
    }

    /// The longest a ring waits for a window that never reports,
    /// counted from the lift (owner ruling, #1959).
    static let arrivalCap: CFTimeInterval = 0.3
    /// How near a report must land to the frame we sent, per
    /// origin axis.
    static let arrivalTolerance: CGFloat = 4

    /// Holds `window`'s ring for this switch, replacing any hold
    /// a previous switch left.
    func holdArrival(
        of window: WindowID,
        notBefore: @escaping @MainActor () -> CFTimeInterval? = { nil }
    ) {
        // A hold this switch replaces must not strand its ring.
        if let old = arrival, old.window != window {
            overlays[old.window]?.reveal(reduceMotion: true)
        }
        arrival = ArrivalHold(
            window: window,
            start: arrivalClock(),
            notBefore: notBefore
        )
        checkArrival()
    }

    /// Whether `sync` orders `window`'s ring in dormant: a held
    /// window's ring that is not showing yet. A ring already
    /// showing — a window that travels with the user — ends the
    /// hold, since there is nothing left to wait for.
    func ordersDormant(_ window: WindowID, overlay: BorderOverlay) -> Bool {
        guard arrival?.window == window else { return false }
        guard overlay.needsOrder else {
            arrival = nil
            return false
        }
        if arrival?.target == nil {
            arrival?.target = commandedFrame(window)
        }
        return true
    }

    /// A report of `window` at `frame` — an AX echo or a
    /// WindowServer move — reveals a held ring once it lands near
    /// the frame we sent.
    func noteArrivalReport(_ window: WindowID, frame: CGRect) {
        guard var hold = arrival, hold.window == window, !hold.arrived
        else { return }
        if hold.target == nil {
            hold.target = commandedFrame(window)
            arrival = hold
        }
        guard let sent = hold.target ?? specs[window]?.frame,
            abs(frame.minX - sent.minX) <= Self.arrivalTolerance,
            abs(frame.minY - sent.minY) <= Self.arrivalTolerance
        else { return }
        hold.arrived = true
        arrival = hold
        checkArrival()
    }

    /// Reveals the held ring when its time has come, else asks to
    /// be called again when it will have.
    func checkArrival() {
        guard let hold = arrival else { return }
        let now = arrivalClock()
        let gate = max(hold.start, hold.notBefore() ?? hold.start)
        let due =
            now < gate
            ? gate
            : hold.arrived ? now : gate + Self.arrivalCap
        guard now >= due else {
            scheduleArrivalCheck(due - now) { [weak self] in
                guard self?.arrival?.start == hold.start else { return }
                self?.checkArrival()
            }
            return
        }
        arrival = nil
        overlays[hold.window]?.reveal(reduceMotion: reduceMotion())
    }
}
