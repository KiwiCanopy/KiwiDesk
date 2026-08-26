import Foundation

/// Diagnostic narration for the close-return family
/// (#951/#952): one syslog line per removal that lost focus,
/// naming every input the return raise weighs — the stand-down
/// arms, the fold's pick and the raise guards — so a live
/// capture names WHICH leg moved focus, or that none did.
/// Diagnosis only, no behavior; called from `handle` after the
/// close-return tail so the needle windows in
/// `CloseReturnStandDownWiringTests` stay untouched.
extension KiwiCore {
    /// "w<id>" or "none" — shared by the focus-leg narration
    /// in `KiwiCore+FocusEvents.swift`.
    func describe(_ id: WindowID?) -> String {
        id.map { "w\($0.raw)" } ?? "none"
    }

    func logCloseReturnDecision(
        event: KiwiEvent,
        effects: AppliedEffects,
        standsDown: Bool
    ) {
        guard let removed = effects.removedWindow,
            removed.focusLost
        else { return }
        let own = eventLoop.ownKeyWindow()
        let ownText =
            own.map {
                "#\($0.number) dialog=\($0.isDialog)"
            } ?? "none"
        // #1007's diagnosis round: which window LEFT.
        // `standsDown` alone cannot say why it holds, and on
        // device it was false for a departure the recorder had
        // just logged — a question the trace could not answer
        // and a rebuild had to.
        let goneText =
            event.goneWindowID.map { "w\($0.raw)" } ?? "unnamed"
        let next = activeSpace?.focused
        let nextText =
            next.map { id -> String in
                let listed = eventLoop.isListed(id)
                let fs =
                    state.windows[id]?.isFullscreen == true
                return "w\(id.raw) listed=\(listed) fs=\(fs)"
            } ?? "none"
        onLog(
            "close-return: removed focused window of "
                + "\(removed.app ?? "?") "
                + "(\(removed.bundleID ?? "?")), "
                + "gone=\(goneText), "
                + "hide=\(event.isHideDrop), "
                + "ownKey=\(ownText), "
                + "standsDown=\(standsDown), "
                + "next=\(nextText)"
        )
    }
}
