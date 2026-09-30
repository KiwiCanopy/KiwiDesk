import Foundation

/// Temporary Spaces (#1790): a live Space that no source declares
/// belongs to no arrangement until it is added to the profile. It
/// is dropped on a switch — never on a config load — and deleted
/// once emptied. The ruling is on the issue and in
/// `docs/design-decisions.md`.
extension KiwiCore {
    /// Whether `id` is a live temporary Space: a profile or a
    /// Standard is live, and `id` is live but not its, nor
    /// `init.lua`'s, not held, and not the system's own (a heal
    /// seed, the placeholder). DERIVED, so a declaration ends it
    /// and any way of making a Space begins it — there is no third
    /// state to fall into. With no arrangement live there is none
    /// to stand outside of, so nothing is temporary.
    public func isTemporary(_ id: SpaceID) -> Bool {
        liveHome != nil
            && state.workspaces[id] != nil
            && state.heldSpaces[id] == nil
            && state.placeholderSpace != id
            && !healedSpaces.values.contains(id)
            && !isDeclared(id)
    }

    /// Whether a source re-creates `id` at the next load — the
    /// question `declaredSources(of:)` answers with names.
    func isDeclared(_ id: SpaceID) -> Bool {
        profiles.active?.declaredSpaces.contains(id) == true
            || profiles.standard?.spaces.contains(id) == true
            || initDeclaredSpaces.contains(id)
    }

    /// Every live temporary Space, in live order.
    var liveTemporarySpaces: [SpaceID] {
        state.workspaces.allSpaces.map(\.id).filter(isTemporary)
    }

    /// The live Spaces the profile does not hold, in live order:
    /// the temporary ones, then the held ones (#1790).
    public var liveOnlySpaces: [LiveOnlySpace] {
        let temporary = liveTemporarySpaces.compactMap { id in
            state.workspaces[id].map {
                LiveOnlySpace(
                    id: id,
                    kind: .temporary,
                    mode: $0.mode,
                    icon: tiler.settings.spaceIcons[id],
                    canAdd: canAddToProfile(id)
                )
            }
        }
        let held = state.workspaces.allSpaces.compactMap { space in
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

    /// `pins` — an arrangement's, about to replace the live ones —
    /// with the live pins of `temporaries` kept: they are in no
    /// arrangement, so none restates them, and a reload or a Save
    /// must not move a New Space off the screen it was made on. The
    /// caller hands the set it read before the apply, less what the
    /// apply declares, since mid-apply the adoption is the outgoing
    /// one.
    func keepingPins(
        of temporaries: Set<SpaceID>,
        over pins: [SpaceID: String]
    ) -> [SpaceID: String] {
        let kept = spacePins.filter { temporaries.contains($0.key) }
        return pins.merging(kept) { own, _ in own }
    }

    /// Whether `id` lived on a screen no longer connected and still
    /// holds windows — what a monitor change's hold takes (#1507).
    func departsWithWindows(_ id: SpaceID) -> Bool {
        guard let screen = spacePins[id] ?? state.settlingScreens[id],
            !liveFingerprints.contains(screen)
        else { return false }
        return !withAwayMembers(state.workspaces[id]?.windows ?? [], of: id)
            .isEmpty
    }

    /// Arms each temporary Space that holds something, and deletes
    /// each armed one that holds nothing any more — once no screen
    /// shows it, and never a screen's last Space, which the #1175
    /// heal would mint straight back. Returns whether any went.
    @discardableResult
    func retireEmptiedTemporarySpaces() -> Bool {
        guard profiles.arrangementInFlight == 0 else { return false }
        let temporaries = liveTemporarySpaces
        // A Space declared since it was armed is not temporary now.
        state.temporaryArmed.formIntersection(temporaries)
        var retired = false
        for id in temporaries {
            guard spaceHoldsNothing(id) else {
                state.temporaryArmed.insert(id)
                continue
            }
            guard state.temporaryArmed.contains(id), !isShown(id),
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
