import Foundation
import Testing

@testable import KiwiDesk

/// The Spaces & Layouts area against the census (#678 Phase 3,
/// turn 8).
///
/// As in General and Gaps & Borders the promise is the WEAKER one:
/// both containers are bespoke views (the space list is one
/// hand-built row per space; the override editor switches on the
/// active layout to a hand-built row set), so the order lists
/// record membership for the placement table and search without
/// driving anything on screen. What is guarded is that the lists
/// and the census agree, and that the bespoke declaration stays
/// true of the tree.
@Suite("Spaces & Layouts render ↔ census parity")
struct SpacesCensusRenderTests {
    /// Rows the census places in this area's container, at a tier
    /// this area draws (`.atRest` / `.showMore`). Lua-only and
    /// internal rows carry no container and are excluded already,
    /// but the tier filter says so rather than relying on it.
    private func censusRows(
        _ container: SettingsContainer
    ) -> Set<SettingKey> {
        Set(
            SettingKey.allCases.filter {
                $0.placement.area == .spacesAndLayouts
                    && $0.placement.container == container
                    && [.atRest, .showMore]
                        .contains($0.placement.tier)
            }
        )
    }

    @Test("each container renders exactly its census rows")
    func listsMatchCensus() {
        for (container, order) in SpacesRowOrder.byContainer {
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
                .filter { $0.placement.area == .spacesAndLayouts }
                .filter {
                    [.atRest, .showMore]
                        .contains($0.placement.tier)
                }
                .compactMap { $0.placement.container }
        )
        #expect(
            declared == Set(SpacesRowOrder.byContainer.keys)
        )
    }

    /// The bespoke claim, read off the TREE rather than restated
    /// against another literal: a container is bespoke exactly when
    /// nothing `ForEach`es its order list. The space list is drawn
    /// by `SpacesSection`, the overrides by `SpaceOverrideRows`, so
    /// both trees are scanned.
    @Test("the bespoke containers really have no ForEach")
    func bespokeMeansNoForEach() throws {
        #expect(
            SpacesRowOrder.bespokeContainers
                == Set(SpacesRowOrder.byContainer.keys)
        )
        let root = SourceScan.repoRoot(from: #filePath)
        var files = try SourceScan.swiftSources(
            under: root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/"
                    + "SpaceOverrides"
            )
        )
        files += try SourceScan.swiftSources(
            under: root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections"
            )
        ).filter {
            $0.lastPathComponent.hasPrefix("SpacesSection")
        }
        // Assert the scan found its input before asserting about
        // it: an enumerator over a renamed directory yields [] and
        // every check below would pass for having looked at
        // nothing.
        #expect(files.count >= 10)
        for file in files {
            let source = SourceScan.blankingCommentsAndLiterals(
                try String(contentsOf: file, encoding: .utf8)
            )
            let squashed = source.split(
                whereSeparator: \.isWhitespace
            ).joined()
            #expect(
                !squashed.contains("ForEach(SpacesRowOrder."),
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
}
