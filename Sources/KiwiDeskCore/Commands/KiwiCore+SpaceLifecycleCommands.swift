import Foundation

/// Space lifecycle commands: create, delete, rename. Runtime
/// operations over the live state (the Settings app owns the
/// persistent GUI-config equivalents). Split from the
/// display-placement verbs for single responsibility.
extension KiwiCore {
    /// `create_space(space [, mode] [, scope])` — brings a space
    /// into existence (spaces otherwise appear implicitly on first
    /// reference), optionally setting its layout mode, and resolves
    /// it onto a display. A no-op beyond the mode set if the space
    /// already exists. A Space it makes is temporary (#1790) unless
    /// `scope` is `profile`, which writes it into the live
    /// profile's file too — an existing temporary Space included.
    /// `scope` may stand in the mode's place: no mode is spelled
    /// like a scope (`SpaceScopeTests`).
    func createSpace(_ args: [JSONValue]) -> CommandResponse {
        guard let raw = args.first?.stringValue else {
            return .fail("expected space id")
        }
        let space = SpaceID(raw)
        var mode: LayoutMode?
        var scope = SpaceScope.session
        for arg in args.dropFirst().compactMap(\.stringValue) {
            if let parsed = LayoutMode(rawValue: arg), mode == nil {
                mode = parsed
            } else if let parsed = SpaceScope(rawValue: arg) {
                scope = parsed
            } else {
                return .fail(
                    "expected \(LayoutMode.expectedList)"
                        + " or \(SpaceScope.expectedList)"
                )
            }
        }
        // The refusal comes before the Space exists.
        if scope == .profile, let refusal = profileScopeRefusal(of: space) {
            return .fail(refusal.description)
        }
        state.workspaces.ensureSpace(space)
        if let mode { setSpaceMode(space, mode) }
        if scope == .profile {
            if case .failure(let refusal) = addToProfile(space) {
                return .fail(refusal.description)
            }
        }
        // Give the new space a display (auto / main) so it can be
        // shown, then apply.
        resolveSpaceDisplays()
        retile(pass: .apply)
        emitSpaceChange()
        return .ok()
    }

    /// `delete_space(space [, scope])` — removes a space after rehoming its
    /// windows to the fallback space (or the first surviving space),
    /// so no window is orphaned. Clears the space from every runtime
    /// map (placement pins, Main role, per-space settings). Runtime
    /// only: a space still declared in `init.lua` or the profile
    /// reappears on the next config load, and `data.declared_in`
    /// names every such source (#1509, `declaredSources(of:)`).
    /// Refuses to delete the only space. `scope` `profile` also
    /// removes it from the live profile's file (#1790) — the CLI's
    /// confirmation — and refuses a Space another source declares.
    func deleteSpace(_ args: [JSONValue]) -> CommandResponse {
        guard let raw = args.first?.stringValue else {
            return .fail("expected space id")
        }
        let space = SpaceID(raw)
        guard state.workspaces[space] != nil else {
            return .fail("unknown space: \(raw)")
        }
        var scope = SpaceScope.session
        if args.count > 1, let scopeRaw = args[1].stringValue {
            guard let parsed = SpaceScope(rawValue: scopeRaw) else {
                return .expected(SpaceScope.self)
            }
            scope = parsed
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
        if scope == .profile,
            case .failure(let refusal) = removeFromProfile(space)
        {
            return .fail(refusal.description)
        }
        forwardWindows(of: space, to: target)
        endHold(of: space)
        tiler.settings.removeSpace(space)
        // The sidecar's list mirrors live (#77), so the delete
        // keeps it faithful or the cold-boot seed re-injects
        // the space (#1509).
        syncGuiSpacesToLive()
        spacePins[space] = nil
        mainSpaces.remove(space)
        if fallbackSpace == space { fallbackSpace = nil }
        resolveSpaceDisplays()
        // The rehomed windows now belong to `target`, whose
        // display just settled above: floats from the deleted
        // space's display re-anchor; `target`'s own floats
        // no-op (#444).
        reanchorFloats(of: target)
        retile(pass: .apply)
        emitSpaceChange()
        let declared = declaredSources(of: space)
        guard !declared.isEmpty else { return .ok() }
        return .ok(
            .object([
                "declared_in": .array(declared.map { .string($0) })
            ])
        )
    }
}
