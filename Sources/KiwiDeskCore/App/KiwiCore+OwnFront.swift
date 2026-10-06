import Foundation

/// The GUI's fronts of its own windows (#1861): a focus report
/// from an own window KiwiDesk itself just brought forward is
/// intended, never a z-order echo.
extension KiwiCore {
    /// How long after the GUI fronts an own window its focus
    /// report is still that front's — the z-order echo window,
    /// since the report it outranks is aged on that bound.
    static let ownFrontWindow: TimeInterval = zOrderRaiseEchoWindow

    /// The GUI's front of own window `number`, reached through
    /// `NSApplication.forceFront` alone. Main actor; prunes by
    /// age. A number that is no window id is ignored.
    public func noteOwnFront(number: Int) {
        guard let id = EventLoop.ownWindowID(number: number) else {
            return
        }
        let now = wallClock()
        ownFronts = ownFronts.filter {
            now.timeIntervalSince($0.value) < Self.ownFrontWindow
        }
        ownFronts[id] = now
    }

    /// Whether the GUI fronted `id` within `ownFrontWindow`.
    /// Read by PRESENCE, unlike the echo ledgers' order reads
    /// (#887): the front is an intent, so its report is honored
    /// whichever raise stamped the window last — the close-return
    /// restack that stamps it lands AFTER the front (#1861).
    func ownFrontIntended(_ id: WindowID, now: Date) -> Bool {
        guard let at = ownFronts[id] else { return false }
        return now.timeIntervalSince(at) < Self.ownFrontWindow
    }

    /// Ends every front once focus is honored on a tracked window of
    /// ANOTHER app (an untracked one leaves it to age out): the
    /// user went elsewhere, so a later echo of a fronted window is
    /// a raise again, not that front's report. A shuffle among our
    /// own windows keeps them — the window a close hands focus
    /// back to may report between the front and the stamp (#1861).
    func retireOwnFronts(honoring id: WindowID) {
        guard !ownFronts.isEmpty,
            let pid = state.windows[id]?.pid,
            !EventLoop.isOwnProcess(pid)
        else { return }
        ownFronts.removeAll()
    }
}
