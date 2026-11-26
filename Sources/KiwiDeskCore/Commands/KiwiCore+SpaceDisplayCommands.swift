import Foundation

/// Space↔display commands (multi-monitor): move a space to a
/// monitor at runtime, or pin it there persistently. Split from
/// `KiwiCore+SpaceCommands.swift` (which owns window-in-space
/// verbs) for the file ceiling.
extension KiwiCore {
    /// Resolves a display argument to a live `DisplayID`:
    /// - a **number** is Screen N (`numberedScreens`, #3647);
    /// - a **string** matches a connected monitor by `fingerprint`
    ///   (as printed by `list_monitors`), else by `name`.
    /// Nil when nothing matches (or no displays are connected).
    func resolveDisplayArg(_ arg: JSONValue?) -> DisplayID? {
        resolveDisplayArg(arg, among: state.workspaces.allDisplays)
    }

    /// `resolveDisplayArg(_:)` over `displays`.
    func resolveDisplayArg(
        _ arg: JSONValue?,
        among displays: [Display]
    ) -> DisplayID? {
        guard !displays.isEmpty else { return nil }
        // Index first: a number is Screen N, never a name (#3647).
        if let number = arg?.intValue {
            return numberedScreens(displays)
                .first { $0.number == number }?.display.id
        }
        guard let name = arg?.stringValue else { return nil }
        if let match = displays.first(where: {
            $0.fingerprint == name
        }) {
            return match.id
        }
        return displays.first { $0.name == name }?.id
    }

    /// `move_space_to_display(space, display)` — moves a space to
    /// another monitor NOW and shows it there. Runtime only: a
    /// later screen change (dock/undock), profile apply or config
    /// load reverts to the space's pin or auto placement — use
    /// `pin_space_to_display` to make it stick. Auto-creates the
    /// space if new.
    func moveSpaceToDisplay(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let raw = args.first?.stringValue else {
            return .fail("expected space id")
        }
        guard
            let area = resolveAreaArg(args.count > 1 ? args[1] : nil)
        else {
            return .fail("expected display index or name")
        }
        let space = SpaceID(raw)
        state.workspaces.ensureSpace(space)
        state.workspaces.assign(space, to: area)
        // The one relocation that bypasses the resolve, so it
        // heals the screen it may have emptied itself (#1175).
        healEmptyDisplays(mainID: PositionalDisplays.liveMainID)
        // Show it on — and move focus to — the target display.
        state.workspaces.activate(space)
        // The layout carries the tiled members to the new
        // display; floats have no layout frame, so each one
        // re-anchors explicitly (#444).
        reanchorFloats(of: space)
        spaceSwitchRetile(asSwitch: true)
        emitSpaceChange()
        return .ok()
    }

    /// `pin_space_to_display(space, display)` — pins a space to a
    /// monitor by that monitor's fingerprint, so the assignment
    /// survives dock/undock (and, declared in `init.lua`, a
    /// relaunch). Overrides any Main-role assignment. Auto-creates
    /// the space if new.
    ///
    /// Sets the RUNTIME pin and re-resolves; it does not hand-write
    /// `gui.json` — under a GUI-managed config the Settings Canvas
    /// stays the persistent pin owner, so a pin set here is a
    /// session override there. Under a Lua-managed config the
    /// declarative `init.lua` re-exec is the persistence. While no
    /// screen is reported the pin is held and answers ok unjudged;
    /// an unmatched name is logged at the first report (#3631).
    func pinSpaceToDisplay(
        _ args: [JSONValue]
    ) -> CommandResponse {
        let stored = storeSpacePin(args)
        guard case .stored(let space) = stored else {
            return stored.response
        }
        // Places the pinned Space alone, so another Space's hand
        // move holds (#3578); the resolve re-anchors the floats of
        // whatever it relocates (#444), a heal's seed included.
        resolveSpaceDisplays(of: [space])
        retile(pass: .apply)
        emitSpaceChange()
        return .ok()
    }

    /// Writes the pin `args` name into `spacePins`, or holds it in
    /// `heldScreenCalls` while no screen is known: a cold boot runs
    /// `init.lua` before any is published (#3631). Resolves
    /// nothing; the caller places.
    func storeSpacePin(_ args: [JSONValue]) -> SpacePinStore {
        guard let raw = args.first?.stringValue else {
            return .refused(.fail("expected space id"))
        }
        let space = SpaceID(raw)
        let arg = args.count > 1 ? args[1] : nil
        if state.workspaces.allDisplays.isEmpty, let arg {
            state.workspaces.ensureSpace(space)
            heldScreenCalls.removeAll { $0.pinnedSpace == space }
            heldScreenCalls.append(.pin(space, arg))
            return .held
        }
        guard
            let area = resolveAreaArg(arg),
            let key = state.workspaces[placement: area]?.key
        else {
            return .refused(.fail("expected display index or name"))
        }
        state.workspaces.ensureSpace(space)
        spacePins[space] = key.description
        // A pin and the Main role are mutually exclusive
        // placements (`SpacePlacement` precedence); a fresh pin
        // wins, so drop any stale Main designation.
        mainSpaces.remove(space)
        return .stored(space)
    }
}

/// `storeSpacePin`'s outcome: written, held for a screen, refused.
enum SpacePinStore {
    case stored(SpaceID)
    case held
    case refused(CommandResponse)

    var response: CommandResponse {
        if case .refused(let response) = self { return response }
        return .ok()
    }
}
