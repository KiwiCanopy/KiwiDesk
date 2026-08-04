import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Profiles family seam's instance derivations (#678 turn
/// 13a) — the lists the three bespoke containers actually draw.
///
/// Split from `ProfilesCensusRenderTests`, which holds the seam
/// against the CENSUS; this holds the derivations against their
/// own rules. The two fail apart: a container could draw the
/// right number of rows in the wrong order, or the right order
/// over the wrong set.
///
/// These matter only because the views consult them
/// (`ProfilesGateWiringTests.viewsConsultTheFamilySeam` pins
/// that). A derivation nothing renders from would be a fixture
/// testing itself.
@Suite("Profiles family rows")
struct ProfilesFamilyRowsTests {
    private func summary(
        _ name: String,
        count: Int,
        matchesLive: Bool
    ) -> ProfileSummary {
        ProfileSummary(
            name: name,
            count: count,
            sets: [],
            isDefault: false,
            matchesLive: matchesLive,
            spaceCount: 0,
            shortcutOverrideCount: 0
        )
    }

    /// Matching hardware first — the card's caption promises one
    /// of them loads — then by screen count, then by name.
    /// One count throughout, so the match state is the only
    /// thing that can decide the order — a fixture that varied
    /// the count too would pass on the count rule alone.
    @Test("profiles matching the live displays lead")
    func orderPutsMatchingFirst() {
        let ordered = ProfilesFamilyRows.orderedProfiles([
            summary("Alpha", count: 3, matchesLive: false),
            summary("Beta", count: 3, matchesLive: false),
            summary("Zed", count: 3, matchesLive: true),
        ])
        #expect(ordered.map(\.name) == ["Zed", "Alpha", "Beta"])
    }

    /// Within one match state, the count orders before the name
    /// — two profiles for the same hardware sit together.
    @Test("count outranks name among non-matching profiles")
    func orderIsCountThenName() {
        let ordered = ProfilesFamilyRows.orderedProfiles([
            summary("Beta", count: 3, matchesLive: false),
            summary("Alpha", count: 3, matchesLive: false),
            summary("Solo", count: 1, matchesLive: false),
        ])
        #expect(ordered.map(\.name) == ["Solo", "Alpha", "Beta"])
    }

    /// Every present desktop, plus any number already bound —
    /// a binding to a now-absent Space stays visible and
    /// clearable rather than silently lost.
    @Test("desktops union the present and the bound")
    func desktopsUnionBindings() {
        #expect(
            ProfilesFamilyRows.desktops(
                present: 2,
                bound: [5]
            ) == [1, 2, 5]
        )
        // A bound number that is also present appears once.
        #expect(
            ProfilesFamilyRows.desktops(
                present: 3,
                bound: [2]
            ) == [1, 2, 3]
        )
    }

    /// No detected desktops is not "1 desktop": with SkyLight
    /// unavailable the count is 0 and only bound numbers show.
    @Test("no detected desktops lists only bound numbers")
    func desktopsWithNonePresent() {
        #expect(
            ProfilesFamilyRows.desktops(
                present: 0,
                bound: [4]
            ) == [4]
        )
        #expect(
            ProfilesFamilyRows.desktops(
                present: 0,
                bound: [Int]()
            ).isEmpty
        )
    }

    /// The two preset lists partition the catalog: every preset
    /// is in exactly one of them, whatever is plugged in. A
    /// preset falling out of both would silently vanish from the
    /// page.
    ///
    /// Split by screen COUNT, not by name: `Starter` names three
    /// different layouts, one per count, so a name-keyed
    /// disjointness check reds on a correct partition.
    @Test("the two preset lists partition the catalog")
    func presetListsPartition() {
        for screens in 0...4 {
            let mine = ProfilesFamilyRows.presets(
                forScreens: screens
            )
            let others = ProfilesFamilyRows.presets(
                excludingScreens: screens
            )
            #expect(
                mine.allSatisfy { $0.screenCount == screens }
            )
            #expect(
                others.allSatisfy { $0.screenCount != screens }
            )
            #expect(
                mine.count + others.count
                    == StandardProfiles.all.count
            )
        }
        // Vacuity: the sweep must run over a real catalog, and
        // over a count that actually has presets — otherwise
        // every `allSatisfy` above holds over an empty list.
        #expect(StandardProfiles.all.count > 1)
        #expect(
            !ProfilesFamilyRows.presets(forScreens: 1).isEmpty
        )
    }
}
