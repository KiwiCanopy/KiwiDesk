import Foundation

/// The gone reason a `.windowDestroyed` reports (#40), decided
/// on the compositor's word since #1146: a window the WindowServer
/// still hosts on a Desktop nobody shows is `vanished`, one it
/// hosts nowhere is `closed`. The #40 timer read the PREVIOUS
/// switch for a fast app's departure (#1207's trace) and stays
/// only where SkyLight cannot answer.
extension KiwiCore {
    /// The destroy arm's tail: classify, file an away entry for
    /// a `vanished` window, and emit.
    func handleWindowGone(
        _ id: WindowID,
        wasMinimized: Bool,
        effects: AppliedEffects
    ) {
        // An explicit Desktop-move target is paid HERE, at the
        // departure the fold just recorded (#1150): the name
        // replaces the remembered Space, and the arrival's
        // ordinary rule lands the window in it.
        if let space = pendingSpace.claim(id),
            state.redirectDeparture(of: id, to: space)
        {
            // Created at the claim, and only for a departure
            // the redirect took: the arrival's
            // `livingRememberedSpace` needs it to exist, and an
            // expired name or a minimize must leave nothing.
            state.workspaces.ensureSpace(space)
            onLog(
                "move_to_desktop: w\(id.raw) departed — filed "
                    + "under space \(space.raw)"
            )
        }
        let spaces = NativeSpaces.allSpaces()
        let presence = gonePresence(of: id, spaces: spaces)
        let reason = WindowGoneReason.classify(
            wasMinimized: wasMinimized,
            presence: presence
        )
        var desktop: Int?
        if case .hosted(let space, true) = presence, !wasMinimized {
            // The eyeball's question (#1146): a fast app folding
            // before the pointer moved would land here.
            onLog(
                "gone: w\(id.raw) still hosted on shown space "
                    + "\(space) — closed"
            )
        }
        if reason == .vanished,
            case .hosted(let space, _) = presence
        {
            desktop = NativeSpaces.number(of: space, in: spaces)
            recordAwayWindow(
                id,
                removed: effects.removedWindow,
                nativeSpace: space
            )
        }
        emitWindowDestroyed(
            id,
            app: effects.removedWindow?.app,
            bundleID: effects.removedWindow?.bundleID,
            space: effects.removedWindow?.space,
            reason: reason,
            desktop: desktop
        )
    }

    /// The compositor's answer for a window that just left the
    /// AX list. `spaces` is the caller's one topology reading
    /// (profiles.md). A Space the topology does not list reads
    /// as unshown: the ledger's next census corrects a wrong
    /// `vanished`, while a wrong `closed` is never corrected.
    func gonePresence(
        of id: WindowID,
        spaces: [NativeSpace]
    ) -> GonePresence {
        let unknown = GonePresence.unknown(
            sinceDesktopSwitch: Date()
                .timeIntervalSince(lastDesktopSwitch)
        )
        guard !spaces.isEmpty else { return unknown }
        switch desktopMemory.readWindowSpace(id) {
        case .unavailable:
            return unknown
        case .gone:
            return .gone
        case .hosted(let space):
            let shown = spaces.contains {
                $0.id == space && $0.isCurrent
            }
            return .hosted(space: space, shown: shown)
        }
    }
}
