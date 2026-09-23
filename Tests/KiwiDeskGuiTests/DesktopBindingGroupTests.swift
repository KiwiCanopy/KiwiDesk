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
    private let live = DesktopBindingFixture.live
    private let gone = DesktopBindingFixture.gone

    private func summary(_ name: String, count: Int) -> ProfileSummary {
        DesktopBindingFixture.summary(name, count: count)
    }

    private var profiles: [ProfileSummary] {
        DesktopBindingFixture.profiles
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
        let docked = ProfilesFamilyRows.bindingCounts(
            profiles: profiles,
            connected: 2
        )
        #expect(
            docked
                == BindingCounts(
                    leading: 2,
                    others: [1, 3],
                    displaysUnknown: false
                )
        )
        #expect(docked.all == [2, 1, 3])
        let unknown = ProfilesFamilyRows.bindingCounts(
            profiles: profiles,
            connected: 0
        )
        #expect(
            unknown
                == BindingCounts(
                    leading: nil,
                    others: [1, 2, 3],
                    displaysUnknown: true
                )
        )
        // A count no profile is saved for is no group at all,
        // and then nothing leads — for a reason the caption
        // tells from the unknown reading.
        #expect(
            ProfilesFamilyRows.bindingCounts(
                profiles: [summary("Dual", count: 2)],
                connected: 1
            )
                == BindingCounts(
                    leading: nil,
                    others: [2],
                    displaysUnknown: false
                )
        )
    }

    /// Every row once per count, and the orphans last.
    @Test("groups repeat the rows per count and list orphans last")
    func groupsRepeatRowsAndListOrphans() throws {
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
            counts: BindingCounts(
                leading: 2,
                others: [1, 3],
                displaysUnknown: false
            ),
            profileCounts: counts
        )
        try #require(groups.count == 4)
        #expect(groups[0] == .count(2, leads: true, rows: listed))
        #expect(groups[1] == .count(1, leads: false, rows: listed))
        #expect(groups[2] == .count(3, leads: false, rows: listed))
        let liveRow = try #require(listed.first { $0.key == live })
        #expect(
            groups[3]
                == .orphans([
                    OrphanBinding(row: liveRow, profile: "Vanished")
                ])
        )
        // No orphan group where every bound name has a count.
        let clean = ProfilesFamilyRows.bindingGroups(
            rows: rows(bindings: [
                live: DesktopBinding(profiles: ["Laptop"], desktop: 1)
            ]),
            counts: BindingCounts(
                leading: 1,
                others: [],
                displaysUnknown: false
            ),
            profileCounts: counts
        )
        #expect(clean.count == 1)
    }

    /// The row carries its record under EITHER key, so the
    /// census sees the orphan the card draws for a record still
    /// filed under the number twin.
    @Test("a twin-keyed record's orphan reaches the census")
    func twinKeyedOrphanReachesTheCensus() {
        let expander = ProfilesFamilyRows(
            profiles: profiles,
            mainDesktops: [1],
            desktopKeys: [1: live],
            presentKeys: [live, .number(1)],
            desktopScreens: [:],
            bindings: [
                .number(1): DesktopBinding(
                    profiles: ["Vanished"],
                    desktop: 1
                )
            ],
            connectedScreens: 1,
            presets: []
        )
        #expect(
            expander.rows(for: .profiles(.profileBindings))?.last
                == .binding(live, .orphan("Vanished"))
        )
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
                    .binding(live, .count(2, setup: nil)),
                    .binding(live, .count(1, setup: nil)),
                    .binding(live, .count(3, setup: nil)),
                    .binding(live, .orphan("Vanished")),
                ]
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
        #expect(
            card.contains("desktopBlock(row,count:count,leads:leads)")
        )
        #expect(
            card.contains("orphanRow(orphan.row,profile:orphan.profile)")
        )
        // A Desktop's rows are the census's own slots (#1609).
        let block = try squashed("DesktopsGroup+Row.swift")
        #expect(block.contains("ProfilesFamilyRows.slots("))
        // The caption asks the ONE leading derivation, and
        // stands down with no display reading (#1436 review).
        #expect(
            card.contains(
                "ifcounts.leading==nil,!counts.displaysUnknown{"
                    + "caption(noProfileForCount)"
            )
        )
        let row = try squashed("DesktopsGroup+Row.swift")
        #expect(
            row.contains(
                "DesktopBindingRefusal.of(profileCount:$0.count,"
                    + "connected:count)==nil"
            )
        )
    }
}
