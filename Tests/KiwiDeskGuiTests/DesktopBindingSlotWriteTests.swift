import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Desktops card's slot write (#1436): a pick files through
/// the record's own algebra, so it edits ONE count's entries,
/// carries the other slots, settles the number twin and removes
/// a record left empty.
@MainActor
@Suite("Desktop binding slot write (#1436)")
struct DesktopBindingSlotWriteTests {
    private let live = DesktopBindingFixture.live
    private let gone = DesktopBindingFixture.gone

    /// A pick in one count group leaves the other counts'
    /// entries where they are; None clears only that slot; the
    /// record goes when its last entry does.
    @Test("a pick edits one slot and leaves the others")
    func pickEditsOneSlot() {
        let (card, model) = DesktopBindingFixture.makeCard()
        card.write("Laptop", key: live, slot: .count(1, setup: nil))
        #expect(
            model.config.profileBindings[live]?.profiles == ["Laptop"]
        )
        // The projections come from the row it was built from.
        #expect(model.config.profileBindings[live]?.desktop == 1)
        #expect(model.config.profileBindings[live]?.screen == "Built-in")
        card.write("Dual", key: live, slot: .count(2, setup: nil))
        #expect(
            model.config.profileBindings[live]?.profiles
                == ["Laptop", "Dual"]
        )
        // Re-picking a count replaces that count's entry alone.
        model.profileSummaries.append(
            DesktopBindingFixture.summary("Solo", count: 1)
        )
        card.write("Solo", key: live, slot: .count(1, setup: nil))
        #expect(
            model.config.profileBindings[live]?.profiles
                == ["Dual", "Solo"]
        )
        card.write(nil, key: live, slot: .count(2, setup: nil))
        #expect(
            model.config.profileBindings[live]?.profiles == ["Solo"]
        )
        card.write(nil, key: live, slot: .count(1, setup: nil))
        #expect(model.config.profileBindings[live] == nil)
    }

    /// Two entries of one count — a profile re-saved at a
    /// sibling's count — are BOTH replaced by a pick and both
    /// cleared by None, or the picker reads back the survivor
    /// and the pick is lost.
    @Test("a pick replaces every entry of its count")
    func pickReplacesEveryEntryOfItsCount() {
        let (card, model) = DesktopBindingFixture.makeCard()
        model.profileSummaries.append(
            DesktopBindingFixture.summary("Solo", count: 1)
        )
        model.config.profileBindings[live] = DesktopBinding(
            profiles: ["Laptop", "Solo", "Dual"],
            desktop: 7
        )
        model.profileSummaries.append(
            DesktopBindingFixture.summary("Third", count: 1)
        )
        card.write("Third", key: live, slot: .count(1, setup: nil))
        #expect(
            model.config.profileBindings[live]?.profiles
                == ["Dual", "Third"]
        )
        // …and the stale number projection took the row's.
        #expect(model.config.profileBindings[live]?.desktop == 1)
        let seeded = model.config.profileBindings[live]
        model.config.profileBindings[live] = DesktopBinding(
            profiles: ["Laptop", "Solo", "Dual"],
            desktop: seeded?.desktop ?? 1
        )
        card.write(nil, key: live, slot: .count(1, setup: nil))
        #expect(model.config.profileBindings[live]?.profiles == ["Dual"])
    }

    /// An orphan slot's None drops that name and nothing else.
    @Test("clearing an orphan drops only that name")
    func orphanClearDropsTheName() {
        let (card, model) = DesktopBindingFixture.makeCard()
        model.config.profileBindings[live] = DesktopBinding(
            profiles: ["Vanished", "Laptop"],
            desktop: 1
        )
        card.write(nil, key: live, slot: .orphan("Vanished"))
        #expect(
            model.config.profileBindings[live]?.profiles == ["Laptop"]
        )
    }

    /// A record under the number twin is settled onto the stamp
    /// by the write, with its other entries carried — and a
    /// DORMANT row, whose number a live Desktop may hold now,
    /// drops nothing but its own.
    @Test("a write settles the twin onto the stamp")
    func writeSettlesTheTwin() {
        let (card, model) = DesktopBindingFixture.makeCard()
        model.config.profileBindings[.number(1)] = DesktopBinding(
            profiles: ["Dual"],
            desktop: 1
        )
        card.write("Laptop", key: live, slot: .count(1, setup: nil))
        #expect(model.config.profileBindings[.number(1)] == nil)
        #expect(
            model.config.profileBindings[live]?.profiles
                == ["Dual", "Laptop"]
        )
        model.config.profileBindings[.number(1)] = DesktopBinding(
            profiles: ["Dual"],
            desktop: 1
        )
        model.config.profileBindings[gone] = DesktopBinding(
            profiles: ["Laptop"],
            desktop: 1
        )
        card.write(nil, key: gone, slot: .count(1, setup: nil))
        #expect(model.config.profileBindings[gone] == nil)
        #expect(
            model.config.profileBindings[.number(1)]?.profiles == ["Dual"]
        )
    }

    /// With two entries of one count the picker names the one
    /// the gate would pick — the live profile — not the first.
    @Test("the picker names the live entry among two of one count")
    func pickerPrefersTheLiveEntry() {
        let (card, model) = DesktopBindingFixture.makeCard()
        model.profileSummaries.append(
            DesktopBindingFixture.summary("Solo", count: 1)
        )
        model.config.profileBindings[live] = DesktopBinding(
            profiles: ["Laptop", "Solo"],
            desktop: 1
        )
        model.activeProfile = "Solo"
        let all = BindingSlot.count(1, setup: nil)
        #expect(card.boundName(key: live, slot: all) == "Solo")
        model.activeProfile = "Other"
        #expect(card.boundName(key: live, slot: all) == "Laptop")
    }

}
