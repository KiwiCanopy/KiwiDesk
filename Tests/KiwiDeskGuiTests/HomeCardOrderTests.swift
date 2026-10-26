import Testing

@testable import KiwiDesk

/// Home's card offer (#678 turn 9): every destination has a
/// card, the order is the frame's and stays stable across mode
/// flips, and one predicate decides who is offered — Simple's
/// eight, Power User's twelve, the Screens auto-promotion, and the
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

    /// A literal over a derived value on purpose: this is the
    /// conscious-edit tripwire on the size of Home, and growing it
    /// should cost a deliberate edit here.
    @Test("one screen offers twelve cards, two screens thirteen")
    func cardCounts() {
        // 12 / 13 since #2654 retired the Simple / Power User
        // toggle: Screens is the one capability-gated card.
        #expect(offered(displays: 1).count == 12)
        #expect(offered(displays: 2).count == 13)
    }

    @Test("Screens needs a second screen, computed at read")
    func screensNeedsTwoScreens() {
        #expect(!offered(displays: 1).contains(.screens))
        #expect(offered(displays: 2).contains(.screens))
        // Nothing stored the answer: one screen again, gone.
        #expect(!offered(displays: 1).contains(.screens))
    }

    /// A card the Mac cannot use is left out of its slot, never
    /// moved: one screen's sequence is two screens' minus Screens.
    @Test("one screen's order is a subsequence of two screens'")
    func stablePositions() {
        let one = offered(displays: 1)
        let two = offered(displays: 2)
        #expect(two.filter { one.contains($0) } == one)
    }

    /// The #18 axis rides the same predicate: editing a stored
    /// profile withdraws General exactly as the sidebar did —
    /// and the Mac Checklist with it (#1365), the other surface
    /// no profile owns.
    @Test("editing a stored profile withdraws the profileless")
    func storedProfileHidesGeneral() {
        let cards = HomeCardOrder.offered(
            HomeCardOrder.wholeApp,
            displayCount: 1,
            editingStoredProfile: true
        )
        #expect(!cards.contains(.general))
        #expect(!cards.contains(.macChecklist))
        #expect(!cards.contains(.ai))
        #expect(!cards.contains(.kiwiVision))
        #expect(cards.count == 3)
    }

    private func offered(displays: Int) -> [SettingsDestination] {
        HomeCardOrder.offered(
            HomeCardOrder.thisProfile,
            displayCount: displays,
            editingStoredProfile: false
        )
            + HomeCardOrder.offered(
                HomeCardOrder.wholeApp,
                displayCount: displays,
                editingStoredProfile: false
            )
    }
}
