import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Profiles area against the census (#678 Phase 3, turn 13a).
///
/// As in General, Gaps & Borders and Spaces the promise is the
/// WEAKER one: every container here is a bespoke view, because
/// each expands ONE census key into a row per live instance — a
/// saved profile, a Desktop, a preset — which no `ForEach` over
/// an order list can express. So the order lists record
/// membership for the placement table and search without driving
/// anything on screen. What is guarded is that the lists and the
/// census agree, that the bespoke declaration stays true of the
/// tree, and that every key the area places actually expands to
/// rows.
@Suite("Profiles render ↔ census parity")
struct ProfilesCensusRenderTests {
    /// The live screens the preset catalog is derived from since
    /// #678 Phase 4 pass 11. One 27" — a single `.desktop`
    /// screen, so the catalog this suite reasons over is the
    /// one-screen one.
    private let censusSizes = [CGSize(width: 2560, height: 1440)]

    /// A summary carrying only what the expansion reads (the
    /// name and the ordering keys) — the rest of the row's
    /// content belongs to the view, not to this seam.
    private func summary(_ name: String) -> ProfileSummary {
        ProfileSummary(
            name: name,
            count: 1,
            sets: [],
            isDefault: false,
            matchesLive: false,
            // One screen against this suite's one census screen,
            // so every fixture profile ties on the count key and
            // it cannot decide this suite's answers — the order
            // rules are `ProfilesFamilyRowsTests`' to hold.
            matchesConnectedCount: true,
            openingModes: [],
            spaceCount: 0,
            shortcutOverrideCount: 0
        )
    }

    /// Rows the census places in this area's container, at a tier
    /// this area draws (`.atRest` / `.showMore`). Lua-only and
    /// internal rows carry no container and are excluded already,
    /// but the tier filter says so rather than relying on it.
    private func censusRows(
        _ container: SettingsContainer
    ) -> Set<SettingKey> {
        Set(
            SettingKey.allCases.filter {
                $0.placement.area == .profiles
                    && $0.placement.container == container
                    && [.atRest, .showMore]
                        .contains($0.placement.tier)
            }
        )
    }

    @Test("each container renders exactly its census rows")
    func listsMatchCensus() {
        for (container, order) in ProfilesRowOrder.byContainer {
            #expect(
                Set(order) == censusRows(container),
                Comment(
                    rawValue:
                        "\(container) drifted from the census — "
                        + "a row moves by editing the census, "
                        + "and the order list follows"
                )
            )
            #expect(
                order.count == Set(order).count,
                "\(container) lists a row twice"
            )
        }
    }

    /// The area draws no container it does not list, and lists
    /// none it cannot draw.
    @Test("the area holds only the containers it renders")
    func containersMatch() {
        let declared = Set(
            SettingKey.allCases
                .filter { $0.placement.area == .profiles }
                .filter {
                    [.atRest, .showMore]
                        .contains($0.placement.tier)
                }
                .compactMap { $0.placement.container }
        )
        #expect(
            declared == Set(ProfilesRowOrder.byContainer.keys)
        )
    }

    /// The bespoke claim, read off the TREE rather than restated
    /// against another literal: a container is bespoke exactly
    /// when nothing `ForEach`es its order list.
    ///
    /// Stated limit: the needle is `ForEach(ProfilesRowOrder.`,
    /// so a container that walks a LOCAL COPY of a list
    /// (`let order = ProfilesRowOrder.presets; ForEach(order)`)
    /// passes. The `files.count` floor below is what keeps the
    /// scan from passing over nothing at all.
    @Test("the bespoke containers really have no ForEach")
    func bespokeMeansNoForEach() throws {
        #expect(
            ProfilesRowOrder.bespokeContainers
                == Set(ProfilesRowOrder.byContainer.keys)
        )
        let root = SourceScan.repoRoot(from: #filePath)
        var files = try SourceScan.swiftSources(
            under: root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Profiles"
            )
        )
        files += try SourceScan.swiftSources(
            under: root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections"
            )
        ).filter {
            let name = $0.lastPathComponent
            return name.hasPrefix("ProfilesSection")
                || name.hasPrefix("PresetsSection")
        }
        // Assert the scan found its input before asserting about
        // it: an enumerator over a renamed directory yields [] and
        // every check below would pass for having looked at
        // nothing.
        #expect(files.count >= 7)
        for file in files {
            let source = SourceScan.blankingCommentsAndLiterals(
                try String(contentsOf: file, encoding: .utf8)
            )
            let squashed = source.split(
                whereSeparator: \.isWhitespace
            ).joined()
            #expect(
                !squashed.contains("ForEach(ProfilesRowOrder."),
                Comment(
                    rawValue:
                        "\(file.lastPathComponent) walks an order "
                        + "list — that container is no longer "
                        + "bespoke, and bespokeContainers must "
                        + "say so"
                )
            )
        }
    }

    /// Every key the area places expands to at least one row, and
    /// the keys that draw NONE are data rather than a skipped
    /// branch — a renderer reading `rows(for:) ?? []` cannot tell
    /// a key that never draws from one whose rows disappeared.
    ///
    /// Only `isStarterSetup` is in that set here, and it is
    /// Lua-only: a profile identity flag with no Settings surface
    /// at all. A second entry means a container went hand-drawn
    /// and owes the same argument.
    @Test("every placed key expands to rows")
    func familiesExpand() {
        let drawsNothing: Set<SettingKey> = [
            .profiles(.isStarterSetup)
        ]
        let expander = ProfilesFamilyRows(
            profiles: [summary("Desk"), summary("Laptop")],
            mainDesktops: [1, 2, 3],
            boundDesktops: [],
            presets: StandardProfiles.all(sizes: censusSizes)
        )
        let placed = SettingKey.allCases.filter {
            if case .profiles = $0 { return true }
            return false
        }
        #expect(!placed.isEmpty)
        // Vacuity: the allow-list must name real placed keys, or
        // the branch below holds over a set that isn't there.
        #expect(drawsNothing.isSubset(of: Set(placed)))
        for key in placed {
            let rows = expander.rows(for: key)
            if drawsNothing.contains(key) {
                #expect(
                    rows == nil,
                    Comment(
                        rawValue: "\(key.id) draws nothing and "
                            + "must expand to nil"
                    )
                )
            } else {
                #expect(
                    rows?.isEmpty == false,
                    Comment(
                        rawValue: "\(key.id) claims a row tier "
                            + "but expands to nothing"
                    )
                )
            }
        }
    }

    /// Each family expands once per INSTANCE, and the three
    /// instance kinds are distinct. Set equality over
    /// `SettingKey` cannot see any of this: an expansion that
    /// silently collapsed to one row would still satisfy
    /// `familiesExpand`.
    @Test("families expand once per instance")
    func instanceCounts() {
        // A BOUND desktop past the present ones, deliberately:
        // with `boundDesktops: []` this fixture cannot see that
        // input at all, and dropping it from the expansion then
        // passes the whole suite (guard-prover, 2026-08-04) —
        // silently retiring the "a binding to a now-absent Space
        // stays listed, and so stays clearable" promise.
        let expander = ProfilesFamilyRows(
            profiles: [summary("Desk"), summary("Laptop")],
            mainDesktops: [1, 2, 3],
            boundDesktops: [7],
            presets: StandardProfiles.layouts(
                for: 1,
                sizes: censusSizes
            )
        )
        #expect(
            expander.rows(for: .profiles(.profilesLoad))
                == [.profile("Desk"), .profile("Laptop")]
        )
        // Present desktops UNION the bound ones — the absent 7
        // is listed, which is the only way its binding can be
        // read or cleared.
        #expect(
            expander.rows(for: .profiles(.profileBindings))
                == [
                    .desktop(1), .desktop(2), .desktop(3),
                    .desktop(7),
                ]
        )
        // BOTH of the card's actions expand per preset (#859).
        // `familiesExpand` cannot see a collapse to one row — its
        // own docstring says so — so a key missing from HERE is a
        // key whose per-instance expansion nothing holds.
        for key in [ProfilesKey.presetsApply, .presetsLayouts] {
            #expect(
                expander.rows(for: .profiles(key))?.count
                    == StandardProfiles.layouts(
                        for: 1,
                        sizes: censusSizes
                    ).count,
                Comment(rawValue: "\(key) lost its per-preset rows")
            )
        }
        // The preset instance carries the STABLE English name,
        // never the localized one — identity must not move with
        // the GUI language.
        //
        // Stated limit: this assertion cannot be the thing that
        // holds that. `StandardLayout.displayName` is
        // `@MainActor` and `ProfilesFamilyRows` is nonisolated,
        // so the localized substitution does not COMPILE — the
        // claim is sealed by isolation, and under the English
        // test locale the two strings would be equal anyway.
        // Read this as pinning the shape, not as coverage of the
        // identity rule (guard-prover, 2026-08-04).
        #expect(
            expander.rows(for: .profiles(.presetsApply))?
                .contains(.preset("Developer")) == true
        )
    }

    /// A key outside `ProfilesKey` expands to nil rather than to
    /// an empty list, so a renderer cannot mistake a foreign key
    /// for a family that lost its rows.
    @Test("a foreign key expands to nil")
    func foreignKey() {
        let expander = ProfilesFamilyRows(
            profiles: [summary("Desk")],
            mainDesktops: [1],
            boundDesktops: [],
            presets: []
        )
        #expect(
            expander.rows(for: .spaces(.spaceList)) == nil
        )
    }
}
