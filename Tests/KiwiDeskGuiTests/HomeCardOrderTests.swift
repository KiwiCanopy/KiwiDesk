import Testing

@testable import KiwiDesk

/// Home's card offer (#678 turn 9): every destination has a
/// card, the order is the frame's and stays stable, and one
/// predicate decides who is offered — the #18 stored-profile
/// rule, never a hand-negated copy. No card hangs on the screen
/// count (#2690).
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
    @Test("Home offers thirteen cards")
    func cardCounts() {
        #expect(offered().count == 13)
        // Screens shows on one screen too (#2690).
        #expect(offered().contains(.screens))
    }

    /// The #18 axis rides the same predicate: editing a stored
    /// profile withdraws General exactly as the sidebar did —
    /// and the Mac Checklist with it (#1365), the other surface
    /// no profile owns.
    @Test("editing a stored profile withdraws the profileless")
    func storedProfileHidesGeneral() {
        let cards = HomeCardOrder.offered(
            HomeCardOrder.wholeApp,
            editingStoredProfile: true
        )
        #expect(!cards.contains(.general))
        #expect(!cards.contains(.macChecklist))
        #expect(!cards.contains(.ai))
        #expect(!cards.contains(.kiwiVision))
        #expect(cards.count == 3)
    }

    private func offered() -> [SettingsDestination] {
        HomeCardOrder.offered(
            HomeCardOrder.thisProfile,
            editingStoredProfile: false
        )
            + HomeCardOrder.offered(
                HomeCardOrder.wholeApp,
                editingStoredProfile: false
            )
    }
}
