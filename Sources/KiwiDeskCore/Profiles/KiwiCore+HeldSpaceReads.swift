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
