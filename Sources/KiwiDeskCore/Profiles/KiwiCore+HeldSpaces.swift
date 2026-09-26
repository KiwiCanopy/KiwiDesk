import Foundation

/// Held Spaces (#1507): a monitor change that switches profile
/// carries each Space of a screen that is gone, and still holds
/// windows, onto a remaining screen instead of forwarding its
/// windows into the incoming profile's fallback. The ruling is on
/// the issue and in `docs/design-decisions.md`.
extension KiwiCore {
    /// The arrangement live now, as a held Space's origin names
    /// it — a Space goes home only into the one it left.
    var liveArrangement: HeldOrigin.Arrangement? {
        if let name = profiles.currentName { return .profile(name) }
        return profiles.currentStandard.map { .standard($0) }
    }

    /// Marks the departing Spaces the prune must keep. A Space
    /// that lived on a screen no longer connected — its pin, else
    /// the screen `settlingScreens` recorded at the report, which
    /// reaches a Main-role or auto-placed Space — and holds windows
    /// (live or away) is held under its own name, or under the
    /// next number past every live one where the incoming
    /// profile declares that name or the held order needs it
    /// (#1664). Runs before the prune, while
    /// `spacePins`, `icons` and `liveArrangement` are still the
    /// departing arrangement's.
    func holdDepartingSpaces(
        declared: Set<SpaceID>,
        icons: [SpaceID: String]
    ) {
        let live = Set(liveFingerprints)
        let candidates: [(Space, String)] = state.workspaces.allSpaces
            .compactMap { space in
                guard state.heldSpaces[space.id] == nil,
                    let screen = spacePins[space.id]
                        ?? state.settlingScreens[space.id],
                    !live.contains(screen),
                    !withAwayMembers(space.windows, of: space.id).isEmpty
                else { return nil }
                return (space, screen)
            }
        // Every live number is taken — a Space the prune is about
        // to drop still exists, and numbering into it would merge.
        let taken = declared.union(state.heldSpaces.keys)
            .union(state.workspaces.allSpaces.map(\.id))
        let names = Self.orderedHeldNames(
            candidates.map(\.0.id),
            taken: taken,
            mustMove: declared.contains
        )
        var focus = heldFocusTrackers()
        for ((space, screen), id) in zip(candidates, names) {
            let origin = HeldOrigin(
                name: space.id,
                screen: screen,
                icon: icons[space.id],
                arrangement: liveArrangement
            )
            if id != space.id {
                moveMembers(of: space.id, to: id, mode: space.mode)
                focus.spaceFocus[id] = space.focused
            }
            state.heldSpaces[id] = origin
            onLog(
                "monitor change: held space \(id.raw) from "
                    + "'\(origin.screenName)'"
                    + (id == origin.name ? "" : " (was \(origin.name.raw))")
            )
        }
        focus.restore(into: &state.workspaces)
        placeHeldBatchLast(names)
    }

    /// Whether a held Space goes home at this apply: its screen is
    /// back, the incoming arrangement is the one it left, and that
    /// arrangement declares its name.
    private func returnsHome(
        _ origin: HeldOrigin,
        declared: Set<SpaceID>,
        into arrangement: HeldOrigin.Arrangement
    ) -> Bool {
        liveFingerprints.contains(origin.screen)
            && (origin.arrangement == nil
                || origin.arrangement == arrangement)
            && declared.contains(origin.name)
    }

    /// A held id is never a declared one: every apply door calls
    /// this FIRST with the set it makes authoritative, and a held
    /// Space whose number that set claims moves to the next free
    /// number — unless it is about to go home under that very name.
    /// The walk and the batch follow the bar, never the dictionary
    /// (#1664); a Space the set does not claim keeps its number.
    func reclaimHeldNames(
        declared: Set<SpaceID>,
        into arrangement: HeldOrigin.Arrangement
    ) {
        let live = state.workspaces.allSpaces.map(\.id)
        let orphans = state.heldSpaces.keys
            .filter { state.workspaces[$0] == nil }
            .sorted {
                (Int($0.raw) ?? .max, $0.raw) < (Int($1.raw) ?? .max, $1.raw)
            }
        let held = (live + orphans).filter { id in
            guard let origin = state.heldSpaces[id] else { return false }
            let goesHome =
                origin.name == id
                && returnsHome(origin, declared: declared, into: arrangement)
            return !goesHome
        }
        var taken = declared.union(state.heldSpaces.keys).union(live)
        let names = held.map { id -> SpaceID in
            guard declared.contains(id) else { return id }
            let fresh = SpaceID.nextNumber(past: taken)
            taken.insert(fresh)
            return fresh
        }
        guard names != held else { return }
        var focus = heldFocusTrackers()
        for (id, fresh) in zip(held, names) where fresh != id {
            guard let origin = state.heldSpaces[id] else { continue }
            let mode = state.workspaces[id]?.mode ?? .bsp
            focus.spaceFocus[fresh] = focus.spaceFocus[id]
            moveMembers(of: id, to: fresh, mode: mode)
            state.heldSpaces[id] = nil
            state.heldSpaces[fresh] = origin
            onLog(
                "held space \(id.raw) renumbered \(fresh.raw): "
                    + "the arrangement declares \(id.raw)"
            )
        }
        focus.restore(into: &state.workspaces)
        placeHeldBatchLast(names)
    }

    /// Sends home every held Space `returnsHome` allows: everything
    /// inside goes into its origin Space and the held one retires.
    /// One whose screen is back but that does not return stays
    /// held, pinned home. Returns the Spaces that went home under
    /// their own name, whose mode the caller now owes.
    @discardableResult
    func refileHeldSpaces(
        declared: Set<SpaceID>,
        into arrangement: HeldOrigin.Arrangement
    ) -> [SpaceID] {
        var inPlace: [SpaceID] = []
        for (id, origin) in state.heldSpaces
        where liveFingerprints.contains(origin.screen) {
            guard
                returnsHome(origin, declared: declared, into: arrangement)
            else {
                spacePins[id] = origin.screen
                continue
            }
            state.heldSpaces[id] = nil
            if id == origin.name {
                inPlace.append(id)
            } else {
                for window in awayMembers(of: id) {
                    state.refileAway(of: window, to: origin.name)
                }
                forwardWindows(of: id, to: origin.name)
                tiler.settings.removeSpace(id)
            }
            onLog(
                "monitor change: returned held space \(id.raw) to "
                    + "\(origin.name.raw) on '\(origin.screenName)'"
            )
        }
        return inPlace
    }

    /// The monitor-change arms that keep the live profile run no
    /// apply, so they send its held Spaces home here — reclaim,
    /// re-file and the returning mode, as an apply would.
    func returnHeldSpacesWithoutApply(to profile: Profile) {
        guard !state.heldSpaces.isEmpty else { return }
        let arrangement = HeldOrigin.Arrangement.profile(profile.name)
        reclaimHeldNames(
            declared: profile.declaredSpaces,
            into: arrangement
        )
        for id in refileHeldSpaces(
            declared: profile.declaredSpaces,
            into: arrangement
        ) {
            setSpaceMode(id, profile.spaceModes[id] ?? .bsp)
        }
    }

    /// Ends one Space's hold — `delete_space` removed it.
    func endHold(of id: SpaceID) {
        state.heldSpaces[id] = nil
    }

    /// Retires every held Space nothing is in any more — no live
    /// member, no away member, no window remembered there that
    /// will come back (a hidden app's; a closed one will not) —
    /// #1507 ruling 4. Returns whether any retired.
    @discardableResult
    func retireEmptiedHeldSpaces() -> Bool {
        var retired = false
        for id in state.heldSpaces.keys {
            let space = state.workspaces[id]
            let holdsNothing =
                withAwayMembers(space?.windows ?? [], of: id).isEmpty
                && !state.rememberedSpaces.contains {
                    $0.value.space == id
                        && !state.closedDepartures.contains($0.key)
                }
            guard holdsNothing else { continue }
            state.heldSpaces[id] = nil
            guard space != nil,
                let other = state.workspaces.allSpaces.first(where: {
                    $0.id != id
                })?.id
            else { continue }
            tiler.settings.removeSpace(id)
            spacePins[id] = nil
            forwardWindows(of: id, to: other)
            retired = true
        }
        return retired
    }

    /// The live Spaces an arrangement WRITE captures — Keep, a
    /// Settings Save, the sidecar sync, a profile's partitioning
    /// record — which a held Space never joins (#1507 ruling 5).
    public var capturedSpaces: [Space] {
        state.workspaces.allSpaces.filter {
            state.heldSpaces[$0.id] == nil
        }
    }

    /// The live pins an arrangement write captures — a held
    /// Space's home pin is not the arrangement's.
    var capturedPins: [SpaceID: String] {
        spacePins.filter { state.heldSpaces[$0.key] == nil }
    }

    /// Ends every held Space's record without touching the Space —
    /// an explicit load makes its profile's set authoritative, and
    /// its prune forwards them like any undeclared Space.
    func forgetHeldSpaces() {
        state.heldSpaces = [:]
    }

    /// Moves a Space's members, live and away, into a new one.
    private func moveMembers(
        of source: SpaceID,
        to target: SpaceID,
        mode: LayoutMode
    ) {
        state.workspaces.ensureSpace(target, mode: mode)
        for window in state.workspaces[source]?.windows ?? [] {
            state.workspaces.add(window, to: target)
            reanchorFloat(window, to: target)
            // Its frame is the other Space's layout's (#1177).
            refiledWindows.insert(window)
        }
        for window in awayMembers(of: source) {
            state.refileAway(of: window, to: target)
        }
    }

    /// `WorkspaceManager.add` nils the focus trackers of a window
    /// it moves; the hold is not a focus change.
    private func heldFocusTrackers() -> HeldFocus {
        var spaceFocus: [SpaceID: WindowID] = [:]
        for space in state.workspaces.allSpaces {
            spaceFocus[space.id] = space.focused
        }
        return HeldFocus(
            lastFocused: state.workspaces.lastFocused,
            candidate: state.workspaces.focusReturnCandidate,
            spaceFocus: spaceFocus
        )
    }
}

/// The focus trackers a membership move must not cost.
private struct HeldFocus {
    let lastFocused: WindowID?
    let candidate: WindowID?
    var spaceFocus: [SpaceID: WindowID]

    func restore(into workspaces: inout WorkspaceManager) {
        workspaces.restoreFocusTrackers(
            lastFocused: lastFocused,
            candidate: candidate,
            spaceFocus: spaceFocus
        )
    }
}
