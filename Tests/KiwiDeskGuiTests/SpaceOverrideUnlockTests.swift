import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Spaces half of the #678 8c capability unlock — the twin of
/// `ShortcutsCapabilityUnlockTests`, which pins the same rules for
/// the shortcut override column.
///
/// The defect this closes: `Customize…` rendered on every space
/// row in BOTH modes, and the editor behind it exposes the
/// per-layout parameters that the `.powerUser`-only Layout
/// Defaults area withholds from Simple — so Simple reached the
/// Advanced surface through a side door.
///
/// The trap, stated by the shortcuts suite and equally live here:
/// the cheapest implementation is to gate on the MODE alone. That
/// passes any test that only ever checks Simple-with-nothing and
/// Power-User-with-nothing, and it silently strands a Simple user
/// who already has overrides — they could neither see nor clear
/// them. Every test below therefore names which of the three
/// properties it is holding.
///
/// Two properties are deliberately NOT tested here, because a
/// test of either would assert what the type system already says
/// (tests.md, "Not owed"): that the gate cannot alter what runs —
/// `isOffered` returns `Bool` and touches nothing — and that a
/// space override cannot unlock a deeper surface elsewhere —
/// `HomeCardOrder.isOffered` takes no `TilingSettings`, so the
/// override is not in its reach at all. Both were drafted, both
/// passed by construction rather than by observation, and a test
/// that cannot fail is worse than none (#406).
@MainActor
@Suite("Space override unlock (#678 8c)")
struct SpaceOverrideUnlockTests {
    /// Three spaces, so "the whole list" has peers to be wrong
    /// about — a single-space fixture would pass this suite while
    /// a per-row gate shipped.
    private let spaces = [
        SpaceID("1"), SpaceID("2"), SpaceID("3"),
    ]

    /// Settings carrying one BSP master-count override on
    /// `space`, and nothing else.
    private func settings(
        overriding space: SpaceID?
    ) -> TilingSettings {
        var settings = TilingSettings()
        if let space {
            var bsp = BspOverride()
            bsp.splitRatioH = 0.6
            settings.bsp.override[space] = bsp
        }
        return settings
    }

    // MARK: - The offer is withheld until it is earned

    @Test("Simple with no override anywhere withholds the offer")
    func simpleWithoutOverridesIsLocked() {
        #expect(
            !SpaceOverrideOffer.isOffered(
                mode: .simple,
                settings: settings(overriding: nil),
                spaces: spaces
            )
        )
    }

    @Test("Power User always offers it, overrides or not")
    func powerUserIsAlwaysOffered() {
        #expect(
            SpaceOverrideOffer.isOffered(
                mode: .powerUser,
                settings: settings(overriding: nil),
                spaces: spaces
            )
        )
    }

    // MARK: - The whole list, not the overridden row

    /// The property a per-row gate breaks: one override unlocks
    /// EVERY row, including the two spaces that carry nothing.
    ///
    /// Asserted by asking the predicate about the whole list
    /// while only the middle space is overridden — a gate written
    /// as `count(for: thisRow) > 0` answers false for spaces 1
    /// and 3 and would fail here.
    @Test("one override unlocks the offer for every space")
    func oneOverrideUnlocksTheWholeList() {
        let settings = settings(overriding: spaces[1])
        #expect(
            SpaceOverrideOffer.isOffered(
                mode: .simple,
                settings: settings,
                spaces: spaces
            ),
            "an override on space 2 must unlock rows 1 and 3 too"
        )
        // And it is the LIST that is consulted, not the space:
        // asking with only an unoverridden space present is the
        // locked answer, so the true above came from the list
        // rather than from the mode leaking through.
        #expect(
            !SpaceOverrideOffer.isOffered(
                mode: .simple,
                settings: settings,
                spaces: [spaces[0]]
            ),
            "a list with no overridden space stays locked"
        )
    }

    /// The "collapsing away when the last override is cleared"
    /// half — a state a per-row gate cannot express at all.
    @Test("clearing the last override re-locks the offer")
    func clearingTheLastOverrideRelocks() {
        var live = settings(overriding: spaces[1])
        #expect(
            SpaceOverrideOffer.isOffered(
                mode: .simple,
                settings: live,
                spaces: spaces
            )
        )
        live.bsp.override[spaces[1]] = nil
        #expect(
            !SpaceOverrideOffer.isOffered(
                mode: .simple,
                settings: live,
                spaces: spaces
            ),
            "the offer must collapse with the last override"
        )
    }

    // MARK: - The mode never changes what runs

    /// A Simple user who already has overrides must still reach
    /// them — this is the arm the mode-only gate strands, and the
    /// reason the predicate consults saved state rather than the
    /// mode alone.
    @Test("saved overrides stay reachable in Simple")
    func savedOverridesStayReachableInSimple() {
        let settings = settings(overriding: spaces[0])
        #expect(
            SpaceOverrideOffer.isOffered(
                mode: .simple,
                settings: settings,
                spaces: spaces
            ),
            "a Simple user with overrides must still reach them"
        )
        // The values themselves are untouched by the mode: the
        // offer is chrome, the override is state.
        #expect(settings.overrideFieldCount(for: spaces[0]) == 1)
    }

}
