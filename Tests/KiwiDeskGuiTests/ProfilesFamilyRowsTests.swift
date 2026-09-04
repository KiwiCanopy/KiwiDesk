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
    /// `matchesCount` defaults to false so a fixture states it
    /// only where the count key is what it is testing — the two
    /// flags are separate claims (a fingerprint match is the
    /// stronger one), and defaulting them together would let a
    /// test pass on whichever key happened to fire.
    private func summary(
        _ name: String,
        count: Int,
        matchesLive: Bool,
        matchesCount: Bool = false
    ) -> ProfileSummary {
        ProfileSummary(
            name: name,
            count: count,
            sets: [],
            isDefault: false,
            matchesLive: matchesLive,
            matchesConnectedCount: matchesCount,
            openingModes: [],
            spaceCount: 0,
            shortcutOverrideCount: 0
        )
    }

    /// Matching hardware first — the card's caption promises one
    /// of them loads — then by screen count, then by name.
    /// One count throughout, so the match state is the only
    /// thing that can decide the order — a fixture that varied
    /// the count too would pass on the count rule alone.
    ///
    /// Every row also carries the SAME `matchesCount`, so they
    /// tie on that key too and `matchesLive` is the only thing
    /// left to decide — which is what this test claims to
    /// observe.
    @Test("profiles matching the live displays lead")
    func orderPutsMatchingFirst() {
        let ordered = ProfilesFamilyRows.orderedProfiles([
            summary(
                "Alpha",
                count: 3,
                matchesLive: false,
                matchesCount: true
            ),
            summary(
                "Beta",
                count: 3,
                matchesLive: false,
                matchesCount: true
            ),
            summary(
                "Zed",
                count: 3,
                matchesLive: true,
                matchesCount: true
            ),
        ])
        #expect(ordered.map(\.name) == ["Zed", "Alpha", "Beta"])
    }

    /// Within one match state, the count orders before the name
    /// — two profiles for the same hardware sit together.
    ///
    /// NO fixture matches the connected count, so that key is
    /// inert here and the ordinal count rule is what the
    /// assertion observes. Marking any of them would make this
    /// test pass on the match-count key instead, which is the
    /// other rule's job.
    @Test("count outranks name among non-matching profiles")
    func orderIsCountThenName() {
        let ordered = ProfilesFamilyRows.orderedProfiles([
            summary("Beta", count: 3, matchesLive: false),
            summary("Alpha", count: 3, matchesLive: false),
            summary("Solo", count: 1, matchesLive: false),
        ])
        #expect(ordered.map(\.name) == ["Solo", "Alpha", "Beta"])
    }

    /// The key #789 added, and the defect it removes: a profile
    /// saved for THIS many screens — but for different monitors,
    /// so no fingerprint matches — sorted behind every profile
    /// with fewer screens, because 1 < 2. The card's caption
    /// promises one of these loads, and the one it means was
    /// last.
    ///
    /// Reds the moment the match-count key is removed: without
    /// it the bare count rules and `Solo` leads.
    @Test("a count-matching profile leads a smaller one")
    func countMatchOutranksSmallerCount() {
        let ordered = ProfilesFamilyRows.orderedProfiles([
            summary("Solo", count: 1, matchesLive: false),
            summary(
                "Desk",
                count: 2,
                matchesLive: false,
                matchesCount: true
            ),
        ])
        #expect(ordered.map(\.name) == ["Desk", "Solo"])
    }

    /// No display read yet, so `refreshProfiles` marks nothing
    /// as count-matching: the key is inert rather than wrong and
    /// the order is what it was before the key existed — the
    /// honest answer while the count is unknown, rather than an
    /// arbitrary one.
    @Test("no count match leaves the order alone")
    func noCountMatchIsInert() {
        let ordered = ProfilesFamilyRows.orderedProfiles([
            summary("Desk", count: 2, matchesLive: false),
            summary("Solo", count: 1, matchesLive: false),
        ])
        #expect(ordered.map(\.name) == ["Solo", "Desk"])
    }

    /// Live Desktops by `.number` and no bindings — the shape
    /// every clause below reuses.
    private func liveKeys(_ numbers: Int...) -> [Int: DesktopKey] {
        Dictionary(
            uniqueKeysWithValues: numbers.map { ($0, .number($0)) }
        )
    }

    private func rows(
        onMain: [Int],
        keys: [Int: DesktopKey],
        bindings: [DesktopKey: DesktopBinding] = [:]
    ) -> [Int] {
        ProfilesFamilyRows.desktops(
            onMain: onMain,
            keys: keys,
            bindings: bindings
        )
        .map(\.number)
    }

    /// The MAIN screen's Desktops, plus any Desktop already bound
    /// (#888) — a binding on another screen's Desktop, or on a
    /// now-absent one, stays visible and clearable rather than
    /// silently lost.
    @Test("desktops union the main screen's and the bound")
    func desktopsUnionBindings() {
        #expect(
            rows(
                onMain: [1, 2],
                keys: liveKeys(1, 2, 5),
                bindings: [
                    .number(5): DesktopBinding(
                        profile: "P",
                        desktop: 5
                    )
                ]
            ) == [1, 2, 5]
        )
        // A bound Desktop that is also on main appears once.
        #expect(
            rows(
                onMain: [1, 2, 3],
                keys: liveKeys(1, 2, 3),
                bindings: [
                    .number(2): DesktopBinding(
                        profile: "P",
                        desktop: 2
                    )
                ]
            ) == [1, 2, 3]
        )
    }

    /// A DORMANT record keeps a row of its own even where a live
    /// Desktop holds the number it was last seen at (#1147).
    ///
    /// This is the post-renumber case the lane exists for —
    /// delete a Desktop in the middle and a later one inherits
    /// its number — and collapsing the two made the record
    /// unreachable: no row, no badge, and the picker editing the
    /// live Desktop's binding instead (three reviewers,
    /// 2026-09-04).
    @Test("a dormant record does not collapse into a live row")
    func dormantKeepsItsOwnRow() {
        let gone = DesktopKey.identity(DesktopIdentity(raw: "GONE"))
        let listed = ProfilesFamilyRows.desktops(
            onMain: [1, 2, 3],
            keys: liveKeys(1, 2, 3),
            bindings: [
                gone: DesktopBinding(profile: "P", desktop: 3)
            ]
        )
        #expect(listed.count == 4)
        #expect(listed.map(\.number) == [1, 2, 3, 3])
        // The live row first, the dormant one after it, and only
        // the dormant one badged.
        #expect(listed[2].key == .number(3))
        #expect(!listed[2].isDormant)
        #expect(listed[3].key == gone)
        #expect(listed[3].isDormant)
    }

    /// The main screen's Desktops carry GLOBAL Mission Control
    /// numbers and need not start at 1: with the secondary screen
    /// listed first, main's are 3 and 4. The retired `present:
    /// Int` parameter could only ever mean `1...n`, so it offered
    /// the wrong Desktops on exactly this arrangement (owner QA,
    /// 2026-08-18).
    @Test("a non-contiguous main screen keeps its own numbers")
    func desktopsAreNotRenumbered() {
        #expect(
            rows(onMain: [3, 4], keys: liveKeys(3, 4)) == [3, 4]
        )
        #expect(
            rows(
                onMain: [3, 4],
                keys: liveKeys(1, 3, 4),
                bindings: [
                    .number(1): DesktopBinding(
                        profile: "P",
                        desktop: 1
                    )
                ]
            ) == [1, 3, 4]
        )
    }

    /// No detected desktops is not "1 desktop": with SkyLight
    /// unavailable there are none to offer and only bound
    /// records show, at the numbers they were last seen at.
    @Test("no detected desktops lists only bound records")
    func desktopsWithNonePresent() {
        #expect(
            rows(
                onMain: [],
                keys: [:],
                bindings: [
                    .number(4): DesktopBinding(
                        profile: "P",
                        desktop: 4
                    )
                ]
            ) == [4]
        )
        #expect(rows(onMain: [], keys: [:]).isEmpty)
    }

    /// The two preset lists partition the catalog: every preset
    /// is in exactly one of them, whatever is plugged in. A
    /// preset falling out of both would silently vanish from the
    /// page.
    ///
    /// Split by screen COUNT, not by name, and swept with the
    /// live sizes the count implies — since #678 Phase 4 pass 11
    /// the `Starter` entry is DERIVED from those sizes, so a
    /// sweep passing one fixed size list would ask about a
    /// catalog no Mac ever shows.
    @Test("the two preset lists partition the catalog")
    func presetListsPartition() {
        for screens in 1...4 {
            let sizes = liveSizes(screens)
            let mine = ProfilesFamilyRows.presets(
                forScreens: screens,
                sizes: sizes
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
                    == StandardProfiles.all(sizes: sizes).count,
                "\(screens) screens: the lists lost a preset"
            )
        }
        // Vacuity: the sweep must run over a real catalog, and
        // over a count that actually has presets — otherwise
        // every `allSatisfy` above holds over an empty list.
        #expect(StandardProfiles.all(sizes: liveSizes(1)).count > 1)
        #expect(
            !ProfilesFamilyRows.presets(
                forScreens: 1,
                sizes: liveSizes(1)
            ).isEmpty
        )
    }

    /// The drawer offers no Starter, whatever the live setup.
    ///
    /// Not a tidiness claim: a count you are not running has no
    /// screen SHAPES to choose layouts from, so there is nothing
    /// a Starter for it could be derived from. The drawer is the
    /// workflow layouts alone, and an entry appearing there would
    /// mean someone had invented hardware to derive it from.
    @Test("For other setups never offers a Starter")
    func drawerHasNoStarter() {
        for screens in 0...4 {
            let others = ProfilesFamilyRows.presets(
                excludingScreens: screens
            )
            #expect(
                others.allSatisfy { $0.name != StarterSetup.name },
                "\(screens) screens: the drawer offered a Starter"
            )
        }
        // Vacuity: the drawer must have had something in it.
        #expect(
            !ProfilesFamilyRows.presets(excludingScreens: 1)
                .isEmpty
        )
    }

    private func liveSizes(_ count: Int) -> [CGSize] {
        [CGSize](
            repeating: CGSize(width: 2560, height: 1440),
            count: count
        )
    }
}
