import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Desktops card's screen-setup rows (#1609): a Desktop draws
/// a slot per setup an entry of the group's count is scoped to,
/// then "All other screen setups" last — the ladder's own order —
/// a slot's pick edits that scope alone, and the add menu shows
/// only where there is a setup to tell apart.
@MainActor
@Suite("Desktop binding scope: the card (#1609)")
struct DesktopBindingScopeCardTests {
    private let live = DesktopBindingFixture.live
    private let vision = ["Sidecar:3360x1440"]
    private let wide = ["Sidecar:5120x1440"]

    private func row(
        _ card: DesktopsGroup
    ) throws -> DesktopRow {
        try #require(card.desktopRows.first { $0.key == live })
    }

    @Test("setup slots come first, all other setups last")
    func slotsReadAsTheLadder() throws {
        let (card, _) = DesktopBindingFixture.makeCard()
        card.write("Laptop", key: live, slot: .count(1, setup: nil))
        card.write("Laptop", key: live, slot: .count(1, setup: wide))
        card.write("Laptop", key: live, slot: .count(1, setup: vision))
        // Another count's scoped entry is not this group's slot.
        card.write("Dual", key: live, slot: .count(2, setup: ["A", "B"]))
        #expect(
            ProfilesFamilyRows.slots(
                of: try row(card),
                count: 1,
                profileCounts: card.profileCounts
            ) == [
                .count(1, setup: wide),
                .count(1, setup: vision),
                .count(1, setup: nil),
            ]
        )
    }

    @Test("a slot's pick edits its own scope alone")
    func pickIsScoped() throws {
        let (card, model) = DesktopBindingFixture.makeCard()
        card.write("Laptop", key: live, slot: .count(1, setup: nil))
        card.write("Laptop", key: live, slot: .count(1, setup: vision))
        #expect(
            card.boundName(key: live, slot: .count(1, setup: vision))
                == "Laptop"
        )
        card.write(nil, key: live, slot: .count(1, setup: vision))
        #expect(
            model.config.profileBindings[live]?.entries
                == [.init(profile: "Laptop")]
        )
        #expect(
            card.boundName(key: live, slot: .count(1, setup: vision))
                == nil
        )
    }

    /// A single-setup user sees today's card: no add menu until a
    /// second setup of the count is known, or one is scoped.
    @Test("the add menu shows only with a setup to tell apart")
    func addMenuNeedsTwoSetups() throws {
        let (card, model) = DesktopBindingFixture.makeCard()
        let one = ClaimableMonitorSet(
            monitors: ["Built-in:1x1"],
            owner: "Laptop",
            isConnected: true
        )
        model.bindableSetups = [1: [one]]
        #expect(!card.offersSetups(count: 1, row: try row(card)))
        card.write("Laptop", key: live, slot: .count(1, setup: vision))
        #expect(card.offersSetups(count: 1, row: try row(card)))
        card.write(nil, key: live, slot: .count(1, setup: vision))
        model.bindableSetups = [
            1: [
                one,
                ClaimableMonitorSet(
                    monitors: vision,
                    owner: nil,
                    isConnected: false
                ),
            ]
        ]
        #expect(card.offersSetups(count: 1, row: try row(card)))
    }

    @Test("the census expands a Desktop into its slots")
    func censusCarriesTheScope() throws {
        let (card, model) = DesktopBindingFixture.makeCard()
        card.write("Laptop", key: live, slot: .count(1, setup: vision))
        let rows = ProfilesFamilyRows(
            profiles: model.profileSummaries,
            mainDesktops: model.mainDesktops,
            desktopKeys: model.desktopKeys,
            presentKeys: model.presentDesktopKeys,
            desktopScreens: model.desktopScreens,
            bindings: model.config.profileBindings,
            connectedScreens: 1,
            presets: []
        )
        .rows(for: .profiles(.profileBindings))
        let scoped = ProfilesRowInstance.binding(
            live,
            .count(1, setup: vision)
        )
        let others = ProfilesRowInstance.binding(
            live,
            .count(1, setup: nil)
        )
        #expect(rows?.contains(scoped) == true)
        #expect(rows?.contains(others) == true)
    }

    /// A scope moved under an unchanged name still owes the
    /// unsaved list its row (gui.md: every reason the pill shows).
    @Test("a scope-only edit is a diff row naming its screens")
    func scopeOnlyEditIsDiffed() {
        LocalizationManager.shared.select("en")
        var old = GuiConfig()
        old.profileBindings[live] = DesktopBinding(
            profile: "Laptop",
            desktop: 1
        )
        var new = old
        new.profileBindings[live]?.bind("Laptop", setup: vision) {
            _ in 1
        }
        let rows = SettingsValueReadout.profilesRows(
            .profileBindings,
            old: old,
            new: new
        )
        #expect(rows.count == 1)
        #expect("\(rows)".contains("Laptop on Sidecar"))
    }
}
