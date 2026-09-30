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
            && declared.contains(origin.name)
    }

    /// Whether held Space `id` goes home under its own name — the
    /// one Space a renumber spares and a return keeps in place.
    func goesHomeInPlace(
        _ id: SpaceID,
        _ origin: HeldOrigin,
        declared: Set<SpaceID>,
        into arrangement: HeldOrigin.Arrangement
    ) -> Bool {
        id == origin.name
            && returnsHome(origin, declared: declared, into: arrangement)
    }

    /// The held Space `window` belongs to: the one it is a member
    /// of, else the one it is remembered in and will come back to
    /// — a closed window never does (#1561). The one answer to
    /// what a held Space holds (#1507 ruling 4, #1728).
    func heldSpace(holding window: WindowID) -> SpaceID? {
        returningSpace(of: window).flatMap {
            state.heldSpaces[$0] == nil ? nil : $0
        }
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
}
