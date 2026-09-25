import Foundation

/// Held Spaces (#1507): a monitor change that switches profile
/// carries each Space of a screen that is gone, and still holds
/// windows, onto a remaining screen instead of forwarding its
/// windows into the incoming profile's fallback. The ruling is on
/// the issue and in `docs/design-decisions.md`.
extension KiwiCore {
    /// Marks the departing Spaces the prune must keep. A Space
    /// pinned to a screen no longer connected that holds windows
    /// — live or away — is held under its own name, or under the
    /// next number past the live set's last where the incoming
    /// profile declares that name. Runs before the prune, while
    /// `spacePins` is still the departing arrangement's; `icons` is
    /// the departing arrangement's too, the incoming settings being
    /// live by then.
    func holdDepartingSpaces(
        declared: Set<SpaceID>,
        icons: [SpaceID: String]
    ) {
        let live = Set(liveFingerprints)
        var taken = Set(state.workspaces.allSpaces.map(\.id))
            .union(declared)
        var focus = heldFocusTrackers()
        for space in state.workspaces.allSpaces
        where state.heldSpaces[space.id] == nil {
            guard let pin = spacePins[space.id], !live.contains(pin),
                !withAwayMembers(space.windows, of: space.id).isEmpty
            else { continue }
            let origin = HeldOrigin(
                name: space.id,
                screen: pin,
                icon: icons[space.id]
            )
            var id = space.id
            if declared.contains(space.id) {
                id = SpaceID.nextNumber(past: taken)
                taken.insert(id)
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
    }

    /// Sends a held Space home once its screen is back and the
    /// incoming arrangement declares its name: everything inside
    /// goes into that Space, and the held one retires. Its screen
    /// back with the name undeclared, it stays held, pinned home.
    func refileHeldSpaces(declared: Set<SpaceID>) {
        let live = Set(liveFingerprints)
        for (id, origin) in state.heldSpaces
        where live.contains(origin.screen) {
            guard declared.contains(origin.name) else {
                spacePins[id] = origin.screen
                continue
            }
            state.heldSpaces[id] = nil
            if id != origin.name {
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
    var capturedSpaces: [Space] {
        state.workspaces.allSpaces.filter {
            state.heldSpaces[$0.id] == nil
        }
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
