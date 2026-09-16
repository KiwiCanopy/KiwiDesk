import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Desktops card's count groups (#1436, ui-designer ruling
/// 2026-09-16): every Desktop row once per screen count a saved
/// profile exists for, the connected count leading, an orphan
/// group for a bound name no profile carries a count for, and a
/// pick that edits ONE slot of a Desktop's record.
@MainActor
@Suite("Desktop binding count groups (#1436)")
struct DesktopBindingGroupTests {
    private let live = DesktopKey.identity(DesktopIdentity(raw: "LIVE"))
    private let gone = DesktopKey.identity(DesktopIdentity(raw: "GONE"))

    private func summary(_ name: String, count: Int) -> ProfileSummary {
        ProfileSummary(
            name: name,
            count: count,
            sets: [],
            isDefault: false,
            matchesLive: false,
            matchesConnectedCount: false,
            openingModes: [],
            spaceCount: 0,
            shortcutOverrideCount: 0
        )
    }

    private var profiles: [ProfileSummary] {
        [
            summary("Dual", count: 2),
            summary("Laptop", count: 1),
            summary("Triple", count: 3),
        ]
    }

    private var counts: [String: Int] {
        Dictionary(
            profiles.map { ($0.name, $0.count) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private func rows(
        bindings: [DesktopKey: DesktopBinding]
    ) -> [DesktopRow] {
        ProfilesFamilyRows.desktops(
            onMain: [1],
            keys: [1: live],
            present: [live, .number(1)],
            screens: [:],
            bindings: bindings
        )
    }

    /// The connected count leads, the rest ascend; with no
    /// display reading nothing leads and the counts ascend.
    @Test("the connected count leads, the rest ascend")
    func connectedCountLeads() {
        #expect(
            ProfilesFamilyRows.bindingCounts(
                profiles: profiles,
                connected: 2
            ) == [2, 1, 3]
        )
        #expect(
            ProfilesFamilyRows.bindingCounts(
                profiles: profiles,
                connected: 0
            ) == [1, 2, 3]
        )
        // A count no profile is saved for is no group at all.
        #expect(
            ProfilesFamilyRows.bindingCounts(
                profiles: [summary("Dual", count: 2)],
                connected: 1
            ) == [2]
        )
    }

    /// Every row once per count, and the orphans last.
    @Test("groups repeat the rows per count and list orphans last")
    func groupsRepeatRowsAndListOrphans() {
        let bindings: [DesktopKey: DesktopBinding] = [
            live: DesktopBinding(
                profiles: ["Laptop", "Vanished"],
                desktop: 1
            ),
            gone: DesktopBinding(profiles: ["Dual"], desktop: 1),
        ]
        let listed = rows(bindings: bindings)
        let groups = ProfilesFamilyRows.bindingGroups(
            rows: listed,
            counts: [2, 1, 3],
            profileCounts: counts,
            binding: { bindings[$0.key] }
        )
        #expect(groups.count == 4)
        #expect(groups[0] == .count(2, rows: listed))
        #expect(groups[1] == .count(1, rows: listed))
        #expect(groups[2] == .count(3, rows: listed))
        let liveRow = try? #require(listed.first { $0.key == live })
        #expect(
            groups[3]
                == .orphans([
                    OrphanBinding(row: liveRow!, profile: "Vanished")
                ])
        )
        // No orphan group where every bound name has a count.
        let clean = ProfilesFamilyRows.bindingGroups(
            rows: listed,
            counts: [1],
            profileCounts: counts,
            binding: { _ in
                DesktopBinding(profiles: ["Laptop"], desktop: 1)
            }
        )
        #expect(clean.count == 1)
    }

    /// The census expands one instance per (Desktop, slot), so a
    /// row drawn twice is counted twice.
    @Test("the census counts one instance per slot")
    func censusCountsSlots() {
        let expander = ProfilesFamilyRows(
            profiles: profiles,
            mainDesktops: [1],
            desktopKeys: [1: live],
            presentKeys: [live, .number(1)],
            desktopScreens: [:],
            bindings: [
                live: DesktopBinding(
                    profiles: ["Laptop", "Vanished"],
                    desktop: 1
                )
            ],
            connectedScreens: 2,
            presets: []
        )
        #expect(
            expander.rows(for: .profiles(.profileBindings))
                == [
                    .binding(live, .count(2)),
                    .binding(live, .count(1)),
                    .binding(live, .count(3)),
                    .binding(live, .orphan("Vanished")),
                ]
        )
    }

    // MARK: - The slot write

    private func makeCard() -> (DesktopsGroup, SettingsModel) {
        let model = makeTestModel(
            core: makeTestCore(
                configDirectory: FileManager.default
                    .temporaryDirectory
                    .appendingPathComponent(
                        "kiwi-group-\(UUID().uuidString)"
                    )
            )
        )
        model.profileSummaries = profiles
        model.mainDesktops = [1]
        model.desktopKeys = [1: live]
        model.presentDesktopKeys = [live, .number(1)]
        model.desktopScreens = [live: "Built-in"]
        return (DesktopsGroup(model: model), model)
    }

    /// A pick in one count group leaves the other counts'
    /// entries where they are; None clears only that slot; the
    /// record goes when its last entry does.
    @Test("a pick edits one slot and leaves the others")
    func pickEditsOneSlot() {
        let (card, model) = makeCard()
        card.write("Laptop", key: live, slot: .count(1))
        #expect(
            model.config.profileBindings[live]?.profiles == ["Laptop"]
        )
        // The projections come from the row it was built from.
        #expect(model.config.profileBindings[live]?.desktop == 1)
        #expect(model.config.profileBindings[live]?.screen == "Built-in")
        card.write("Dual", key: live, slot: .count(2))
        #expect(
            model.config.profileBindings[live]?.profiles
                == ["Laptop", "Dual"]
        )
        // Re-picking a count replaces that count's entry alone.
        model.profileSummaries.append(summary("Solo", count: 1))
        card.write("Solo", key: live, slot: .count(1))
        #expect(
            model.config.profileBindings[live]?.profiles
                == ["Dual", "Solo"]
        )
        card.write(nil, key: live, slot: .count(2))
        #expect(
            model.config.profileBindings[live]?.profiles == ["Solo"]
        )
        card.write(nil, key: live, slot: .count(1))
        #expect(model.config.profileBindings[live] == nil)
    }

    /// An orphan slot's None drops that name and nothing else.
    @Test("clearing an orphan drops only that name")
    func orphanClearDropsTheName() {
        let (card, model) = makeCard()
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
    /// by the write, with its other entries carried.
    @Test("a write settles the twin onto the stamp")
    func writeSettlesTheTwin() {
        let (card, model) = makeCard()
        model.config.profileBindings[.number(1)] = DesktopBinding(
            profiles: ["Dual"],
            desktop: 1
        )
        card.write("Laptop", key: live, slot: .count(1))
        #expect(model.config.profileBindings[.number(1)] == nil)
        #expect(
            model.config.profileBindings[live]?.profiles
                == ["Dual", "Laptop"]
        )
    }

    /// The view's half no model test sees: the groups are drawn
    /// through the one derivation, each row with its slot, and a
    /// group's picker offers profiles through Core's judgement.
    @Test("the card draws the groups it derives")
    func cardDrawsTheGroups() throws {
        func squashed(_ name: String) throws -> String {
            let path = SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Components/Profiles/"
                        + name
                )
            return SourceScan.stripComments(
                try String(contentsOf: path, encoding: .utf8)
            )
            .split(whereSeparator: \.isWhitespace)
            .joined()
        }
        let card = try squashed("DesktopsGroup.swift")
        #expect(card.contains("ProfilesFamilyRows.bindingGroups("))
        #expect(card.contains("ProfilesFamilyRows.bindingCounts("))
        #expect(card.contains("spaceRow(row,slot:.count(count))"))
        #expect(
            card.contains("spaceRow(orphan.row,slot:.orphan(orphan.profile))")
        )
        #expect(card.contains("caption(noProfileForCount)"))
        let row = try squashed("DesktopsGroup+Row.swift")
        #expect(
            row.contains(
                "DesktopBindingRefusal.of(profileCount:$0.count,"
                    + "connected:count)==nil"
            )
        )
    }
}
