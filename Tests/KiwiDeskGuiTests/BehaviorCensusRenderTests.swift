import Foundation
import Testing

@testable import KiwiDesk

/// The Behaviour area against the census (#678 Phase 3, turn 9 —
/// the twelfth and last area to convert).
///
/// The promise is the WEAKER one, as in General: both containers
/// are bespoke cards, so the order lists record membership for
/// the placement table and for search without driving anything
/// on screen. What is guarded is that the lists and the census
/// agree, and that the bespoke declaration stays true of the
/// tree.
@Suite("Behaviour render ↔ census parity")
struct BehaviorCensusRenderTests {
    /// Rows the census places in this area's container.
    private func censusRows(
        _ container: SettingsContainer
    ) -> Set<SettingKey> {
        Set(
            SettingKey.allCases.filter {
                $0.placement.area == .behaviour
                    && $0.placement.container == container
            }
        )
    }

    @Test("each container renders exactly its census rows")
    func listsMatchCensus() {
        for (container, order) in BehaviorRowOrder.byContainer {
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
                .filter { $0.placement.area == .behaviour }
                .compactMap { $0.placement.container }
        )
        #expect(
            declared == Set(BehaviorRowOrder.byContainer.keys)
        )
    }

    /// Every row here is at rest: the area has no disclosure to
    /// put a `.showMore` row behind, so one gaining that tier
    /// would be hidden with nothing to reveal it.
    @Test("the area holds no show-more rows")
    func noShowMoreRows() {
        for key in SettingKey.allCases
        where key.placement.area == .behaviour {
            #expect(
                key.placement.tier == .atRest,
                Comment(
                    rawValue:
                        "\(key.id) is not .atRest, and the area "
                        + "draws no disclosure to reveal it"
                )
            )
        }
    }

    /// The bespoke claim, read off the TREE rather than restated
    /// against another literal: a container is bespoke exactly
    /// when nothing `ForEach`es its order list.
    @Test("the bespoke containers really have no ForEach")
    func bespokeMeansNoForEach() throws {
        #expect(
            BehaviorRowOrder.bespokeContainers
                == Set(BehaviorRowOrder.byContainer.keys)
        )
        let root = SourceScan.repoRoot(from: #filePath)
        var files = try SourceScan.swiftSources(
            under: root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Behavior"
            )
        )
        files += try SourceScan.swiftSources(
            under: root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections"
            )
        ).filter {
            $0.lastPathComponent.hasPrefix("BehaviorSection")
        }
        // Assert the scan found its input before asserting about
        // it: an enumerator over a renamed directory yields [] and
        // every check below would pass for having looked at
        // nothing.
        #expect(files.count >= 2)
        for file in files {
            let source = SourceScan.blankingCommentsAndLiterals(
                try String(contentsOf: file, encoding: .utf8)
            )
            let squashed = source.split(
                whereSeparator: \.isWhitespace
            ).joined()
            #expect(
                !squashed.contains("ForEach(BehaviorRowOrder."),
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
