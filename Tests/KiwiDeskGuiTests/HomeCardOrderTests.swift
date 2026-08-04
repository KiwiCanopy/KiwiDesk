import Testing

@testable import KiwiDesk

/// Home's card offer (#678 turn 9): every destination has a
/// card, the order is the frame's and stays stable across mode
/// flips, and one predicate decides who is offered — Simple's
/// eight, Power User's twelve, the Monitors auto-promotion, and the
/// #18 stored-profile rule, never a hand-negated copy.
@Suite("Home card order and offer")
struct HomeCardOrderTests {
    @Test("every destination draws exactly one card")
    func everyDestinationHasACard() {
        let all =
            HomeCardOrder.thisProfile + HomeCardOrder.wholeApp
        #expect(Set(all).count == all.count)
        #expect(
            Set(all) == Set(SettingsDestination.allCases)
        )
    }

    /// The grid's scope split must agree with the navigation's
    /// own grouping — a card in the wrong group would say a
    /// profile setting is app-wide.
    @Test("the groups match the destination groups")
    func groupsMatch() {
        #expect(
            Set(HomeCardOrder.thisProfile)
                == Set(SettingsDestination.thisProfile)
        )
        #expect(
            Set(HomeCardOrder.wholeApp)
                == Set(SettingsDestination.wholeApp)
        )
    }

    /// NINE since Layout Defaults moved to `.simple` (owner
    /// ruling 2026-08-04) — those parameters are how people learn
    /// what a tiling manager does, so withholding them teaches
    /// nothing. A literal over a derived value on purpose: this
    /// is the conscious-edit tripwire on the size of the
    /// first-week surface, and growing it should cost a
    /// deliberate edit here.
    @Test("Simple offers nine cards, Power User twelve")
    func modeCounts() {
        let simple = offered(mode: .simple, displays: 1)
        let powerUser = offered(mode: .powerUser, displays: 1)
        #expect(simple.count == 9)
        #expect(powerUser.count == 12)
    }

    /// Power User INSERTS, never reorders: Simple's sequence is
    /// Power User's with its extra cards removed, so no card
    /// moves when the segment flips.
    @Test("Simple is a subsequence of Power User")
    func stablePositions() {
        let simple = offered(mode: .simple, displays: 1)
        let powerUser = offered(mode: .powerUser, displays: 1)
        #expect(
            powerUser.filter { simple.contains($0) } == simple
        )
    }

    @Test("Monitors auto-promotes into Simple at two displays")
    func monitorsPromotes() {
        #expect(
            !offered(mode: .simple, displays: 1)
                .contains(.monitors)
        )
        let promoted = offered(mode: .simple, displays: 2)
        #expect(promoted.contains(.monitors))
        #expect(promoted.count == 10)
        // Computed at read: one display again and the card is
        // gone — nothing stored the promotion.
        #expect(
            !offered(mode: .simple, displays: 1)
                .contains(.monitors)
        )
    }

    /// The #18 axis rides the same predicate: editing a stored
    /// profile withdraws General exactly as the sidebar did.
    @Test("editing a stored profile withdraws General")
    func storedProfileHidesGeneral() {
        let cards = HomeCardOrder.offered(
            HomeCardOrder.wholeApp,
            mode: .powerUser,
            displayCount: 1,
            editingStoredProfile: true
        )
        #expect(!cards.contains(.general))
        #expect(cards.count == 3)
    }

    private func offered(
        mode: SettingsMode,
        displays: Int
    ) -> [SettingsDestination] {
        HomeCardOrder.offered(
            HomeCardOrder.thisProfile,
            mode: mode,
            displayCount: displays,
            editingStoredProfile: false
        )
            + HomeCardOrder.offered(
                HomeCardOrder.wholeApp,
                mode: mode,
                displayCount: displays,
                editingStoredProfile: false
            )
    }
}
