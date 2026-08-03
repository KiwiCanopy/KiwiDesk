import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Layout Defaults area renders FROM the census (#678 Phase
/// 3, turn 10): the census owns placement, `LayoutDefaultsRowOrder`
/// owns display order. These pin the two together — every
/// `.layoutDefaults`-area census key appears in exactly the order
/// list its placement names, so a census row added, retiered or
/// moved without a renderer update is a red test, not a silently
/// missing control.
@Suite("Layout Defaults render ↔ census parity")
struct LayoutDefaultsCensusRenderTests {
    private func censusRows(
        _ container: SettingsContainer,
        _ tier: SettingTier = .atRest
    ) -> Set<SettingKey> {
        Set(
            SettingKey.allCases.filter {
                $0.placement.area == .layoutDefaults
                    && $0.placement.container == container
                    && $0.placement.tier == tier
            }
        )
    }

    /// Membership and freedom-from-duplicates for every list at
    /// once, driven by the mode → container map rather than by a
    /// hand-written case per layout: a seventh tuned layout is
    /// then covered by existing code, and one that forgot its
    /// order list reds here instead of rendering an empty card.
    @Test("each layout's rows are that container's census rows")
    func everyLayoutMatchesItsContainer() {
        for mode in LayoutMode.placementTabs {
            let container = try? #require(
                LayoutDefaultsRowOrder.container(for: mode)
            )
            guard let container else { continue }
            let rendered = LayoutDefaultsRowOrder.rows(for: mode)
            #expect(
                Set(rendered) == censusRows(container),
                Comment(
                    rawValue:
                        "\(mode) renders \(rendered.count) rows, "
                        + "census says "
                        + "\(censusRows(container).count)"
                )
            )
            #expect(rendered.count == Set(rendered).count)
        }
    }

    /// The row above the strip — shared by all seven layouts, so
    /// it sits in its own container and not inside one of them.
    @Test("the shared row is the general container's census row")
    func generalRow() {
        #expect(
            Set(LayoutDefaultsRowOrder.general)
                == censusRows(.general)
        )
    }

    /// The area's render knows exactly these containers; one more
    /// would mount nowhere, so it must fail loud here rather than
    /// ship an unreachable row. Derived from the mode map plus
    /// the shared container, so adding a layout to
    /// `placementTabs` and to `container(for:)` is enough.
    @Test("the area holds only the containers it renders")
    func onlyRenderedContainers() {
        let declared = Set(
            SettingKey.allCases
                .filter { $0.placement.area == .layoutDefaults }
                .compactMap { $0.placement.container }
        )
        let rendered = Set(
            LayoutMode.placementTabs.compactMap {
                LayoutDefaultsRowOrder.container(for: $0)
            }
        )
        #expect(declared == rendered.union([.general]))
    }

    /// Tier ↔ chrome. A set-equality guard is blind to chrome: it
    /// would stay green with rows tiered `.showMore` and drawn at
    /// rest, because both sides are the same set either way. The
    /// area draws no disclosure at all, so a `.showMore` row here
    /// would render at rest while claiming to be hidden — pin the
    /// tier, and pin that no disclosure appears in the area's
    /// views to render one with.
    @Test("nothing in this area is behind a disclosure")
    func noRowIsBehindADisclosure() throws {
        // The two tiers that mean "not at rest, one interaction
        // away" — NOT every tier past `.atRest`. A `.luaOnly`
        // parameter has no chrome to hide behind either, and is
        // exactly what the census records for a layout knob the
        // GUI deliberately withholds; banning it here would make
        // a correct placement red a guard about disclosures.
        let deeper = SettingKey.allCases.filter {
            $0.placement.area == .layoutDefaults
                && [.showMore, .immediate]
                    .contains($0.placement.tier)
        }
        #expect(
            deeper.isEmpty,
            Comment(
                rawValue:
                    "tiered as hidden with no chrome to draw "
                    + "them: \(deeper.map(\.id))"
            )
        )
        let files = try areaSources()
        for file in files {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            #expect(
                !source.contains("SettingsDisclosure("),
                Comment(
                    rawValue:
                        "\(file.lastPathComponent) draws a "
                        + "disclosure — the tier pin above stops "
                        + "meaning anything the moment one exists"
                )
            )
        }
        // A floor, because the enumerator behind `areaSources()`
        // yields an EMPTY sequence for a missing directory rather
        // than throwing — so a rename of the area's directory,
        // which gui.md makes an obligation when a destination is
        // renamed, would leave this half passing having scanned
        // nothing (guard-prover, 2026-08-03). The number is the
        // schematics plus the row/gate/render files; it only has
        // to be high enough that an empty scan cannot reach it.
        #expect(
            files.count >= 13,
            Comment(
                rawValue:
                    "scanned \(files.count) files — the area's "
                    + "directory has moved and this guard is "
                    + "looking at nothing"
            )
        )
    }

    /// Ruling 5: a guard over a literal restated against a
    /// literal documents, it does not detect. So the "every
    /// layout is reachable" claim is read off the TREE — the
    /// strip's own `ForEach` over `LayoutMode.placementTabs` —
    /// rather than off a copy of the list. Paired with
    /// `SettingsCatalogArgumentTests`, which pins that the card
    /// is mounted once and parameterized, this is what makes the
    /// six per-layout search anchors reachable.
    @Test("the strip walks every layout")
    func stripWalksEveryLayout() throws {
        let strip = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Layouts/"
                    + "LayoutStrip.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: strip, encoding: .utf8)
        )
        // The `ForEach`'s OWN first argument, not two independent
        // `contains` over the file: with the loop walking
        // `allCases` and `placementTabs` merely mentioned
        // elsewhere in the same file, a substring pair goes green
        // over a strip that mounts a Floating tile whose card has
        // no container (guard-prover, 2026-08-03).
        let sources = SourceScan.firstArguments(
            of: "ForEach(",
            in: source
        )
        #expect(
            sources.contains("LayoutMode.placementTabs"),
            Comment(
                rawValue:
                    "LayoutStrip's ForEach walks \(sources) — not "
                    + "the curated layout list, so the tiles and "
                    + "the search index no longer agree"
            )
        )
        // And the list itself is the six tuned layouts —
        // Floating has nothing to tune, so a tile for it would
        // open an empty card.
        #expect(
            Set(LayoutMode.placementTabs)
                == Set(LayoutMode.allCases).subtracting([
                    .floating
                ])
        )
    }

    /// Every file that could draw this area's chrome — the
    /// components directory AND the section that composes them.
    /// The section is the area's own `body` and the likeliest
    /// place a disclosure would land, so scanning only the
    /// components directory watched everywhere but the door.
    private func areaSources() throws -> [URL] {
        let root = SourceScan.repoRoot(from: #filePath)
        return try SourceScan.swiftSources(
            under: root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Layouts"
            )
        )
            + [
                root.appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Sections/"
                        + "LayoutDefaultsSection.swift"
                )
            ]
    }
}
