import Foundation

/// The native Desktop verbs (#884, unlocking #25/#26):
/// `focus_desktop`, `move_to_desktop` and
/// `move_to_desktop_and_follow` — the Desktop-side twins of
/// `focus_space` / `move_to_space(_and_follow)`, driven through
/// `WMBridge` on stock macOS with SIP on.
///
/// **A Desktop number is its Mission Control number** — the
/// GLOBAL one, counted across every screen, which is what
/// `bind_profile_to_desktop` already keys on (#888:
/// `DesktopSnapshot.mainDisplayDesktops` documents "a binding
/// keys on that global number"). The verb resolves it in ONE
/// snapshot through `DesktopSnapshot.space(numbered:)`, the
/// inverse of the numbering authority, and then acts on the
/// screen that Desktop lives on — a Desktop has exactly one.
///
/// That is a deliberate REFINEMENT of #890's resolution
/// principle, not a reading of it: the ruling says a number
/// resolves against one screen's list, picking the screen first
/// (moves → the window's screen, switches → the focused
/// screen). Resolving globally instead keeps ONE meaning for
/// "Desktop 3" across bindings, the Profiles card and these
/// verbs; the per-screen reading would give the same number two
/// meanings in one app, which is the defect the Desktop/Space
/// vocabulary ruling exists to remove.
///
/// The device question that decided it, answered 2026-08-25 on
/// two screens with "Displays have separate Spaces" ON: **Mission
/// Control numbers Desktops globally** — the main screen's were
/// labelled 1–2 and the second screen's 3–5, continuing the
/// count rather than restarting it. So the global number IS the
/// number on screen, and a verb, a binding and the Profiles card
/// all name a Desktop the same way. Recorded on #890.
///
/// **Performed is not applied** (os-private-apis.md): the bridge
/// returns nothing a caller can trust. A switch is confirmed by
/// the OS's own notification, which runs `handleDesktopChange`
/// exactly as a swipe does — device-observed 2026-08-25: after
/// `focus_desktop`, the target Desktop's window census replaced
/// the previous one, which only `reconcileAll` on that
/// notification produces. A move has no such signal, so the
/// no-follow path arms its own reap.
extension KiwiCore {
    /// The resolved target of a Desktop verb: the WindowServer
    /// space id and the identifier of the screen it lives on.
    struct DesktopTarget: Equatable {
        let space: SkyLight.SpaceID
        let displayIdentifier: String
        /// The space that screen shows NOW, from the same
        /// snapshot the target resolved in (#888: one reading,
        /// every question) — the space a switch must hide,
        /// because the pointer write performs no transition of
        /// its own (#1023). Nil when the snapshot cannot say.
        let originSpace: SkyLight.SpaceID?
        /// The topology the target resolved in, threaded so the
        /// dispatch asks it every question (#888) — the sticky
        /// reach stamp classifies render screens off it (#1213).
        let spaces: [NativeSpace]

        /// Whether the Desktop is already the one its screen
        /// shows — a switch to it is a no-op. Derived, so a
        /// hand-built target cannot carry origin and verdict in
        /// disagreement.
        var isCurrent: Bool { originSpace == space }
    }

    /// Resolves a 1-based Mission Control number against one
    /// topology reading, or nil when no user Desktop has it or
    /// the topology cannot name that Desktop's screen (an
    /// unnamed screen would dispatch an empty identifier and
    /// report success).
    static func desktopTarget(
        number: Int,
        in snapshot: DesktopSnapshot
    ) -> DesktopTarget? {
        guard let space = snapshot.space(numbered: number),
            !space.displayUUID.isEmpty
        else { return nil }
        return DesktopTarget(
            space: space.id,
            displayIdentifier: space.displayUUID,
            originSpace: snapshot.currentSpaces[space.displayUUID],
            spaces: snapshot.spaces
        )
    }

    /// A verb's parse: the target, or the response that refuses.
    /// Internal since the §2.1 split: the move verbs consume it
    /// one file over (`KiwiCore+DesktopMove.swift`).
    enum DesktopResolution {
        case target(DesktopTarget)
        case refused(CommandResponse)
    }

    /// The parse shared by the three verbs: the capability
    /// first, then the argument. Capability before anything a
    /// caller could get wrong, so a macOS without the bridge
    /// always answers the same refusal rather than reporting
    /// whichever precondition it happened to check first.
    func resolveDesktopArgument(
        _ args: [JSONValue]
    ) -> DesktopResolution {
        guard canDriveDesktops else {
            return .refused(
                .fail("desktop bridge unavailable on this macOS")
            )
        }
        guard let number = args.first?.intValue, number >= 1 else {
            return .refused(.fail("expected Desktop number (1-based)"))
        }
        guard
            let target = Self.desktopTarget(
                number: number,
                in: NativeSpaces.desktopSnapshot()
            )
        else {
            return .refused(.fail("no Desktop \(number)"))
        }
        return .target(target)
    }

    /// A move verb's optional second argument: the KiwiDesk Space
    /// the window joins when it lands (#1150).
    enum SpaceTargetResolution {
        case none
        case space(SpaceID)
        case refused(CommandResponse)
    }

    /// Parses the composed `space:` target of a Desktop MOVE
    /// (#1150) — absent for the one-argument form. A Space
    /// assigned to a screen other than the Desktop's is refused
    /// up front: the layout carries a window to its Space's
    /// screen, and macOS then re-assigns its Desktop to match,
    /// which undoes the move within a second (#1010). An
    /// unassigned Space, or one the screen cannot be named for,
    /// is accepted — `screenHome` stands down for it too. A
    /// Space that does not exist yet is created, as
    /// `move_to_space` creates one, so the arrival's
    /// remembered-space rule can honor it (`livingRememberedSpace`
    /// drops a `.departed` record whose Space is gone).
    func resolveSpaceTarget(
        _ args: [JSONValue],
        for target: DesktopTarget
    ) -> SpaceTargetResolution {
        guard args.count > 1 else { return .none }
        guard let raw = args[1].stringValue, !raw.isEmpty else {
            return .refused(.fail("expected space id"))
        }
        let space = SpaceID(raw)
        if let assigned = state.workspaces.display(of: space),
            let screen = display(forUUID: target.displayIdentifier),
            assigned != screen
        {
            return .refused(
                .fail(
                    "space \(raw) lays out on another screen than "
                        + "that Desktop's"
                )
            )
        }
        state.workspaces.ensureSpace(space)
        return .space(space)
    }

    /// `focus_desktop <n>` (#26): switches the Desktop's screen
    /// to it. The OS notification that follows runs the same
    /// switch handling a swipe does — binding, Space memory,
    /// retile, `desktop_change`.
    func focusDesktop(_ args: [JSONValue]) -> CommandResponse {
        switch resolveDesktopArgument(args) {
        case .refused(let response):
            return response
        case .target(let target):
            return switchDesktop(to: target, verb: "focus_desktop")
                .response
        }
    }
}
