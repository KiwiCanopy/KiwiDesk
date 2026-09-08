import Foundation

/// The gone reason a `.windowDestroyed` reports (#40), decided
/// on the compositor's word since #1146: a window the WindowServer
/// still hosts on a Desktop nobody shows is `vanished`, one it
/// hosts nowhere is `closed`. The #40 timer read the PREVIOUS
/// switch for a fast app's departure (#1207's trace) and stays
/// only where SkyLight cannot answer.
extension KiwiCore {
    /// The destroy arm's tail: classify, file an away entry for
    /// a `vanished` window, and emit. Returns the reason, which
    /// the close-return stand-down reads (#1345).
    func handleWindowGone(
        _ id: WindowID,
        wasMinimized: Bool,
        effects: AppliedEffects
    ) -> WindowGoneReason {
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
        return reason
    }

    /// Whether a removal is the window LEAVING WITH ITS DESKTOP
    /// (#1345): `vanished` — hosted on a Desktop nobody shows —
    /// and not a move verb's own departure, recorded by the verb
    /// and claimed here. A swipe's removals are exactly these,
    /// and macOS picks the focus on the Desktop it shows, so the
    /// close-return raise stands down for them the way it does
    /// for a hide (#913). On a host without the compositor read,
    /// `vanished` is the #40 timer's word inside the switch
    /// settle — accepted: that host runs no Desktop machinery.
    func departedWithDesktop(
        _ event: KiwiEvent,
        reason: WindowGoneReason?,
        now: Date = Date()
    ) -> Bool {
        guard let id = event.goneWindowID else { return false }
        let recorded = desktopMoveDepartures.removeValue(forKey: id)
        let moved =
            recorded.map {
                now.timeIntervalSince($0) < Self.desktopMoveDepartureWindow
            } ?? false
        return reason == .vanished && !moved
    }

    /// How long a move verb's departure record may wait for its
    /// vanish: past a slow app's destroy (Electron's trailed the
    /// swipe by up to ~3 s on device, 2026-09-08), and the verb's
    /// bridge write is PERFORMED, not applied (os-private-apis.md),
    /// so a record whose vanish never comes must expire rather
    /// than name the window's next swipe departure as the verb's.
    static let desktopMoveDepartureWindow: TimeInterval = 10

    /// A move verb's own departure (#1345): the vanish that
    /// follows is the verb's hand-off, never a swipe's. Recorded
    /// per window and claimed at the vanish, so a slow app's
    /// destroy seconds later still reads as the verb's. Only
    /// where a vanish is coming: a target its screen already
    /// shows moves the window in view, and a record nothing
    /// claims would name the window's NEXT vanish — a swipe's —
    /// as the verb's.
    func recordDesktopMoveDeparture(
        _ id: WindowID,
        targetIsCurrent: Bool,
        now: Date = Date()
    ) {
        guard !targetIsCurrent else { return }
        desktopMoveDepartures[id] = now
    }

    /// The compositor hosts `id` on a native fullscreen Space —
    /// the removal gate's fullscreen ENTER arm, read through
    /// `EventLoop.fullscreenSpaceHosts` (#1272). The classifier's
    /// own answer (`gonePresence`) against ONE topology reading;
    /// a Space that reading does not list is a user one, so an
    /// unreadable host never refuses a removal. Priced per
    /// vanished window: the two reads `handleWindowGone` pays a
    /// moment later anyway.
    func windowIsOnFullscreenSpace(_ id: WindowID) -> Bool {
        let spaces = NativeSpaces.allSpaces()
        let presence = gonePresence(of: id, spaces: spaces)
        guard case .hosted(let space, _) = presence else { return false }
        return !NativeSpaces.isUserSpace(space, in: spaces)
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
