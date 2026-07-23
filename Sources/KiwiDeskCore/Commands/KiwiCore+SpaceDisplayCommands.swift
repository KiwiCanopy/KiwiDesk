import Foundation

/// Space↔display commands (multi-monitor): move a space to a
/// monitor at runtime, or pin it there persistently. Split from
/// `KiwiCore+SpaceCommands.swift` (which owns window-in-space
/// verbs) for the file ceiling.
extension KiwiCore {
    /// Resolves a display argument to a live `DisplayID`:
    /// - a **number** is a 1-based positional index — main is 1,
    ///   secondaries follow left-to-right (`PositionalDisplays`);
    /// - a **string** matches a connected monitor by `fingerprint`
    ///   (as printed by `list_monitors`), else by `name`.
    /// Nil when nothing matches (or no displays are connected).
    func resolveDisplayArg(_ arg: JSONValue?) -> DisplayID? {
        let displays = state.workspaces.allDisplays
        guard !displays.isEmpty else { return nil }
        // Index first: a numeric arg is positional, never a name.
        if let index = arg?.intValue {
            let ordered = PositionalDisplays.ordered(
                displays,
                mainID: PositionalDisplays.liveMainID
            )
            guard index >= 1, index <= ordered.count else {
                return nil
            }
            return ordered[index - 1].id
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
    /// later monitor re-resolve (dock/undock) reverts to the
    /// space's pin or auto placement — use `pin_space_to_display`
    /// to make it stick. Auto-creates the space if new.
    func moveSpaceToDisplay(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let raw = args.first?.stringValue else {
            return .fail("expected space id")
        }
        guard
            let display = resolveDisplayArg(
                args.count > 1 ? args[1] : nil
            )
        else {
            return .fail("expected display index or name")
        }
        let space = SpaceID(raw)
        state.workspaces.ensureSpace(space)
        state.workspaces.assign(space, to: display)
        // Show it on — and move focus to — the target display.
        state.workspaces.activate(space)
        // The layout carries the tiled members to the new
        // display; floats have no layout frame, so each one
        // re-anchors explicitly (#444).
        reanchorFloats(of: space)
        retile(
            animated: tiler.settings.animations.onSpaceChange,
            force: true
        )
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
    /// declarative `init.lua` re-exec is the persistence.
    func pinSpaceToDisplay(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let raw = args.first?.stringValue else {
            return .fail("expected space id")
        }
        guard
            let display = resolveDisplayArg(
                args.count > 1 ? args[1] : nil
            ),
            let monitor = state.workspaces.allDisplays.first(where: {
                $0.id == display
            })
        else {
            return .fail("expected display index or name")
        }
        let space = SpaceID(raw)
        state.workspaces.ensureSpace(space)
        spacePins[space] = monitor.fingerprint
        // A pin and the Main role are mutually exclusive
        // placements (`SpacePlacement` precedence); a fresh pin
        // wins, so drop any stale Main designation.
        mainSpaces.remove(space)
        resolveSpaceDisplays()
        // A pin that moved the space across displays strands its
        // floats like a window move would (#444); re-anchor them
        // (a same-display pin is a no-op per float).
        reanchorFloats(of: space)
        retile(force: true)
        emitSpaceChange()
        return .ok()
    }

    /// Re-anchors every floating member of `space` onto its
    /// (possibly new) display — the space-level sibling of the
    /// `moveWindow` re-anchor (#444). `reanchorFloat` itself
    /// skips tiled members and same-display cases.
    private func reanchorFloats(of space: SpaceID) {
        for id in state.workspaces[space]?.windows ?? [] {
            reanchorFloat(id, to: space)
        }
    }
}
