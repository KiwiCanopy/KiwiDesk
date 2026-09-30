import Foundation

/// The held Spaces' read-only answers (#1507): which arrangement is
/// live, whether a held Space goes home, and the views an
/// arrangement write captures. Writes no `heldSpaces` — that
/// stays `KiwiCore+HeldSpaces.swift`'s.
extension KiwiCore {
    /// The arrangement live now and the Spaces it declares, from
    /// ONE reading of the adoption state (#1245) — a held Space
    /// goes home only into the arrangement it left.
    var liveHome:
        (arrangement: HeldOrigin.Arrangement, declared: Set<SpaceID>)?
    {
        if let active = profiles.active {
            return (.profile(active.name), active.declaredSpaces)
        }
        if let standard = profiles.standard {
            return (.standard(standard.name), standard.spaces)
        }
        return nil
    }

    /// The arrangement live now, as a held Space's origin names it.
    var liveArrangement: HeldOrigin.Arrangement? {
        liveHome?.arrangement
    }

    /// Whether a held Space goes home at this apply: its screen is
    /// back, the incoming arrangement is the one it left, and that
    /// arrangement declares its name.
    func returnsHome(
        _ origin: HeldOrigin,
        declared: Set<SpaceID>,
        into arrangement: HeldOrigin.Arrangement
    ) -> Bool {
        liveFingerprints.contains(origin.screen)
            && (origin.arrangement == nil
                || origin.arrangement == arrangement)
            && (origin.isTemporary || declared.contains(origin.name))
    }

    /// Whether held Space `id` goes home under its own name — the
    /// one Space a renumber spares and a return keeps in place.
    func goesHomeInPlace(
        _ id: SpaceID,
        _ origin: HeldOrigin,
        declared: Set<SpaceID>,
        into arrangement: HeldOrigin.Arrangement
    ) -> Bool {
        // A temporary one comes back under the number it holds, so
        // one the arrangement declares must move off it first.
        (origin.isTemporary ? !declared.contains(id) : id == origin.name)
            && returnsHome(origin, declared: declared, into: arrangement)
    }

    /// The Space `window` is in, or will come back to — a closed
    /// window comes back as a new one, so it names none.
    func returningSpace(of window: WindowID) -> SpaceID? {
        state.workspaces.space(of: window)
            ?? (state.closedDepartures.contains(window)
                ? nil : state.rememberedSpace(of: window))
    }

    /// Whether nothing is in `id` any more — no live member, no
    /// away member, no window remembered there that will come
    /// back (a hidden app's). The one answer for a held Space's
    /// retire and a Space chip's Delete (#1507, #1790).
    func spaceHoldsNothing(_ id: SpaceID) -> Bool {
        withAwayMembers(state.workspaces[id]?.windows ?? [], of: id)
            .isEmpty
            && !state.rememberedSpaces.keys.contains {
                returningSpace(of: $0) == id
            }
    }

    /// The live Spaces an arrangement WRITE captures — a Settings
    /// Save, the sidecar sync, a profile's partitioning record —
    /// which neither a held Space (#1507 ruling 5) nor a temporary
    /// one (#1790) joins. `save_profile` alone takes
    /// `snapshotSpaces`.
    public var capturedSpaces: [Space] {
        capturedSpaces(alsoOf: [])
    }

    /// `capturedSpaces`, and the temporary Spaces in `extra` — the
    /// ones a draft commit lists and is about to declare.
    func capturedSpaces(alsoOf extra: Set<SpaceID>) -> [Space] {
        snapshotSpaces.filter {
            !isTemporary($0.id) || extra.contains($0.id)
        }
    }

    /// The live Spaces the whole-live snapshot writes: every one
    /// but a held Space, temporary ones included (#1790).
    var snapshotSpaces: [Space] {
        state.workspaces.allSpaces.filter {
            state.heldSpaces[$0.id] == nil
        }
    }

    /// The live pins an arrangement write captures — a held
    /// Space's home pin is not the arrangement's, nor a temporary
    /// one's unless `extra` names it.
    func capturedPins(alsoOf extra: Set<SpaceID>) -> [SpaceID: String] {
        spacePins.filter {
            state.heldSpaces[$0.key] == nil
                && (!isTemporary($0.key) || extra.contains($0.key))
        }
    }

    /// `capturedPins(alsoOf: [])`, for the GUI's draft baseline.
    public var capturedSpacePins: [SpaceID: String] {
        capturedPins(alsoOf: [])
    }

    /// Whether a switch holds `id` though its screen stayed
    /// (#1790): the incoming arrangement does not name it, and it
    /// is temporary or the outgoing one declared it — never a heal
    /// seed or an `init.lua` Space, which no return could take.
    func holdsUnnamed(
        _ id: SpaceID,
        declared: Set<SpaceID>,
        temporaries: Set<SpaceID>
    ) -> Bool {
        guard !declared.contains(id) else { return false }
        if temporaries.contains(id) { return true }
        switch liveArrangement {
        case .profile:
            return profiles.active?.declaredSpaces.contains(id) == true
        case .standard:
            return profiles.standard?.spaces.contains(id) == true
        case nil: return false
        }
    }

    /// The fingerprint of the screen `id` lays out on now; one the
    /// resolve has not placed yet lays out on the main screen.
    func shownScreen(of id: SpaceID) -> String? {
        let display =
            state.workspaces.display(of: id) ?? PositionalDisplays.liveMainID
        let displays = state.workspaces.allDisplays
        return (displays.first { $0.id == display } ?? displays.first)?
            .fingerprint
    }

    /// Whether a held Space joined under a number not its own since
    /// `before` — a renumber owes its ⌃⌥N (#485's top-up).
    func heldRenumbered(since before: Set<SpaceID>) -> Bool {
        state.heldSpaces.contains {
            !before.contains($0.key) && $0.key != $0.value.name
        }
    }
}
