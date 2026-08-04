import KiwiDeskCore

/// The Monitors area's census gates, resolved on the shape the
/// other areas share (#678 Phase 3, turn 13b): a struct keyed on
/// a row's own `SettingKey`, returning a REASON case rather than
/// a Bool, with the answered / answered-elsewhere split held as
/// data.
///
/// **Every gate here SURFACES rather than greys** — the same
/// flavour as `ShortcutsGates.onlyDefaultLayer`, and for the same
/// reason it carries no `GateHelp` companion: there is no
/// why-you-cannot sentence to render beside a dimmed control,
/// because nothing in this area dims. What the gates decide is
/// which of two mutually exclusive things the placement card
/// holds — the picture, or the banner explaining why there isn't
/// one — plus whether the orphaned-pins card exists at all.
///
/// That is not an exception to "grey, don't hide" (gui.md). A
/// greyed control says "switch that on and I act"; a picture of
/// monitors that are not attached has nothing to dim, since its
/// cards ARE the displays and there are none. So the banner takes
/// the picture's place and says so in a sentence, which is the
/// stronger form of the same promise.
///
/// The picture's own rows carry NO gate, and that is deliberate.
/// They were briefly given `.monitorsDisconnected` — the banner's
/// condition — so the census would record why the cards vanish.
/// It records the wrong thing: every census gate reads "shows
/// while true", so one tag on both the banner and the rows it
/// replaces declares a single condition with two opposite
/// meanings, legible only inside this file. The banner's gate
/// already carries the fact; the cards are its complement by
/// construction, and one answer beats two that agree only while
/// somebody remembers to keep them agreeing.
///
/// Pure over the live-state answers it is given, so
/// `MonitorsGateTests` asserts it without a view.
struct MonitorsGates {
    /// Whether the dashboard is editing a stored profile rather
    /// than the live config (#18).
    let editingStoredProfile: Bool
    /// Whether the edit target's monitors are attached, so the
    /// picture has real frames to draw. Live editing is always
    /// editable; a stored profile saved for other hardware is
    /// not.
    let placementEditable: Bool
    /// Whether any space is pinned to a monitor that is not
    /// attached right now.
    let hasOrphanedPins: Bool

    /// Why a row is not on screen right now. One case per
    /// predicate AND per sentence — a reason a renderer can
    /// switch on, rather than a Bool it would have to interpret.
    enum InertReason: Hashable {
        /// The picture IS drawable, so the banner standing in for
        /// it stays away.
        case pictureIsDrawable
        /// Nothing is pinned to a disconnected monitor, so the
        /// card about that has nothing to list.
        case noOrphanedPins
    }

    /// The condition the census names `.monitorsDisconnected`,
    /// resolved once so the two rows reading it cannot disagree.
    var monitorsDisconnected: Bool {
        editingStoredProfile && !placementEditable
    }

    /// Why `key`'s row is withheld right now, or nil while it is
    /// on screen. Fail-OPEN on a gate this type does not own —
    /// loud in debug, surfaced in release — matching the other
    /// area resolvers: of the two silent readings, a row the user
    /// can ignore beats one they cannot find.
    /// `everyGatedRowIsResolved` keeps that arm unreachable
    /// rather than merely believed to be.
    func inertReason(for key: SettingKey) -> InertReason? {
        guard key.placement.gate != nil else { return nil }
        switch key {
        case .monitors(.placementUnavailable):
            return monitorsDisconnected ? nil : .pictureIsDrawable
        case .monitors(.orphanPinClear):
            return hasOrphanedPins ? nil : .noOrphanedPins
        default:
            assertionFailure(
                "unhandled Monitors gate: \(key.id)"
            )
            return nil
        }
    }

    /// The gated rows this resolver answers. Data, so
    /// `everyGatedRowIsResolved` reds when a new census gate in
    /// this area lands in neither set instead of hitting the
    /// fail-open default at run time.
    static let resolved: Set<SettingKey> = [
        .monitors(.placementUnavailable),
        .monitors(.orphanPinClear),
    ]

    /// Declared-but-answered-elsewhere. Empty and kept so a new
    /// gate this resolver cannot answer must land here on purpose
    /// rather than pass silently.
    static let resolvedElsewhere: Set<SettingKey> = []
}
