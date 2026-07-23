import Foundation

/// Space lifecycle commands: create, delete, rename. Runtime
/// operations over the live state (the Settings app owns the
/// persistent GUI-config equivalents). Split from the
/// display-placement verbs for single responsibility.
extension KiwiCore {
    /// `create_space(space [, mode])` — brings a space into
    /// existence (spaces otherwise appear implicitly on first
    /// reference), optionally setting its layout mode, and resolves
    /// it onto a display. A no-op beyond the mode set if the space
    /// already exists.
    func createSpace(_ args: [JSONValue]) -> CommandResponse {
        guard let raw = args.first?.stringValue else {
            return .fail("expected space id")
        }
        let space = SpaceID(raw)
        state.workspaces.ensureSpace(space)
        if args.count > 1, let modeRaw = args[1].stringValue {
            guard let mode = LayoutMode(rawValue: modeRaw) else {
                return .fail("unknown mode: \(modeRaw)")
            }
            state.workspaces.setMode(space, mode)
        }
        // Give the new space a display (auto / main) so it can be
        // shown, then apply.
        resolveSpaceDisplays()
        retile(force: true)
        emitSpaceChange()
        return .ok()
    }

    /// `delete_space(space)` — removes a space after rehoming its
    /// windows to the fallback space (or the first surviving space),
    /// so no window is orphaned. Clears the space from every runtime
    /// map (placement pins, Main role, per-space settings). Runtime
    /// only: a space still declared in `init.lua` / the GUI config
    /// reappears on the next config load. Refuses to delete the only
    /// space.
    func deleteSpace(_ args: [JSONValue]) -> CommandResponse {
        guard let raw = args.first?.stringValue else {
            return .fail("expected space id")
        }
        let space = SpaceID(raw)
        guard state.workspaces[space] != nil else {
            return .fail("unknown space: \(raw)")
        }
        let survivors = state.workspaces.allSpaces
            .map(\.id)
            .filter { $0 != space }
        guard
            let target =
                fallbackSpace.flatMap({
                    survivors.contains($0) ? $0 : nil
                }) ?? survivors.first
        else {
            return .fail("cannot delete the only space")
        }
        for window in state.workspaces[space]?.windows ?? [] {
            state.workspaces.add(window, to: target)
        }
        state.workspaces.removeSpace(space)
        tiler.settings.removeSpace(space)
        spacePins[space] = nil
        mainSpaces.remove(space)
        if fallbackSpace == space { fallbackSpace = nil }
        resolveSpaceDisplays()
        // The rehomed windows now belong to `target`, whose
        // display just settled above: floats from the deleted
        // space's display re-anchor; `target`'s own floats
        // no-op (#444).
        reanchorFloats(of: target)
        retile(force: true)
        emitSpaceChange()
        return .ok()
    }
}
