import Foundation

/// Temporary Spaces (#1790): a Space made on the fly belongs to no
/// arrangement until it is added to the profile. It is dropped on a
/// switch — never on a config load — and deleted once emptied. The
/// ruling is on the issue and in `docs/design-decisions.md`.
extension KiwiCore {
    /// Whether `id` is a live temporary Space.
    public func isTemporary(_ id: SpaceID) -> Bool {
        state.temporarySpaces[id] != nil
    }

    /// The live Spaces the profile does not hold, in live order:
    /// the temporary ones, then the held ones (#1790).
    public var liveOnlySpaces: [LiveOnlySpace] {
        let live = state.workspaces.allSpaces
        let canAdd = profiles.currentName != nil
        let temporary = live.filter { isTemporary($0.id) }.map {
            LiveOnlySpace(
                id: $0.id,
                kind: .temporary,
                mode: $0.mode,
                icon: tiler.settings.spaceIcons[$0.id],
                canAdd: canAdd
            )
        }
        let held = live.compactMap { space in
            state.heldSpaces[space.id].map {
                LiveOnlySpace(
                    id: space.id,
                    kind: .held(screen: $0.screenName),
                    mode: space.mode,
                    icon: $0.icon ?? tiler.settings.spaceIcons[space.id],
                    canAdd: false
                )
            }
        }
        return temporary + held
    }

    /// Settings ▸ Spaces' add button (#1790): `id` into the live
    /// profile, the same write `create_space` with `profile` makes.
    /// False where it could not write.
    @discardableResult
    public func addSpaceToProfile(_ id: SpaceID) -> Bool {
        guard isTemporary(id), case .success = addToProfile(id) else {
            return false
        }
        return true
    }

    /// Marks every Space a command made — one that did not exist
    /// before it ran — as temporary, unless a source declares it,
    /// it is held, or it is the system's own (a heal seed, the
    /// placeholder). `execute`'s alone, so every verb that can
    /// make a Space is covered by one seam; `init.lua`'s run is
    /// declaring, never temporary.
    func markNewSpacesTemporary(since before: Set<SpaceID>) {
        guard !isRunningInitScript else { return }
        let seeds = Set(healedSpaces.values)
        for space in state.workspaces.allSpaces
        where !before.contains(space.id) {
            let id = space.id
            guard state.heldSpaces[id] == nil,
                !seeds.contains(id),
                state.placeholderSpace != id,
                declaredSources(of: id).isEmpty
            else { continue }
            state.temporarySpaces[id] = TemporarySpace(
                armed: !spaceHoldsNothing(id)
            )
        }
    }

    /// `pins` — an arrangement's, about to replace the live ones —
    /// with each temporary Space's own pin kept: it is in no
    /// arrangement, so none restates it, and a reload or a Save
    /// must not move a New Space off the screen it was made on.
    func keepingTemporaryPins(
        _ pins: [SpaceID: String]
    ) -> [SpaceID: String] {
        pins.merging(
            spacePins.filter { state.temporarySpaces[$0.key] != nil }
        ) { own, _ in own }
    }

    /// Whether this apply drops the temporary Spaces: the live
    /// arrangement changes to `incoming`. Nothing live is nothing
    /// to switch from — boot's first apply, a deleted profile.
    func dropsTemporarySpaces(
        into incoming: HeldOrigin.Arrangement
    ) -> Bool {
        liveArrangement.map { $0 != incoming } ?? false
    }

    /// Drops every temporary Space, forwarding its windows the way
    /// the prune forwards an undeclared Space's: into `preferring`
    /// where it survives, else the first of `orderedBy` that does.
    /// Runs after the hold, which keeps a departing one that still
    /// has windows.
    func dropTemporarySpaces(
        orderedBy order: [SpaceID],
        preferring explicit: SpaceID?
    ) {
        let dropped = Set(state.temporarySpaces.keys)
        guard !dropped.isEmpty else { return }
        let survives = { (id: SpaceID) in
            !dropped.contains(id) && self.state.workspaces[id] != nil
        }
        let target =
            explicit.flatMap { survives($0) ? $0 : nil }
            ?? order.first(where: survives)
            ?? state.workspaces.allSpaces.map(\.id).first(where: survives)
        guard let target else { return }
        for id in state.workspaces.allSpaces.map(\.id)
        where dropped.contains(id) {
            tiler.settings.removeSpace(id)
            spacePins[id] = nil
            forwardWindows(of: id, to: target)
            onLog("profile switch: dropped temporary space \(id.raw)")
        }
        state.temporarySpaces = [:]
    }

    /// Arms each temporary Space that holds something, and deletes
    /// each armed one that holds nothing any more — once no screen
    /// shows it, and never a screen's last Space, which the #1175
    /// heal would mint straight back. Returns whether any went.
    @discardableResult
    func retireEmptiedTemporarySpaces() -> Bool {
        var retired = false
        for (id, temporary) in state.temporarySpaces {
            guard state.workspaces[id] != nil else {
                state.temporarySpaces[id] = nil
                continue
            }
            guard spaceHoldsNothing(id) else {
                if !temporary.armed {
                    state.temporarySpaces[id]?.armed = true
                }
                continue
            }
            guard temporary.armed, !isShown(id),
                let other = sibling(onScreenOf: id)
            else { continue }
            tiler.settings.removeSpace(id)
            spacePins[id] = nil
            forwardWindows(of: id, to: other)
            onLog("temporary space \(id.raw) emptied: deleted")
            retired = true
        }
        return retired
    }

    /// Whether any screen shows `id` now.
    private func isShown(_ id: SpaceID) -> Bool {
        state.workspaces.allDisplays.contains {
            state.workspaces.currentSpace(on: $0.id) == id
        }
    }

    /// Another Space on `id`'s screen, if it is not the last one.
    private func sibling(onScreenOf id: SpaceID) -> SpaceID? {
        let screen = state.workspaces.display(of: id)
        return state.workspaces.allSpaces.first {
            $0.id != id && state.workspaces.display(of: $0.id) == screen
        }?.id
    }
}
