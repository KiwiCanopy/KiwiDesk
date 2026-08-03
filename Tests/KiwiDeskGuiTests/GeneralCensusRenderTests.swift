import Foundation
import Testing

@testable import KiwiDesk

/// The General area against the census (#678 Phase 3, turn 14b).
///
/// The promise is the WEAKER one, and this says so rather than
/// implying otherwise: all three containers are bespoke views, so
/// the order lists record membership for the placement table and
/// for search without driving anything on screen. What is
/// guarded is that the lists and the census agree, and that the
/// bespoke declaration stays true of the tree.
@Suite("General render ↔ census parity")
struct GeneralCensusRenderTests {
    /// Rows the census places in this area's container at a tier.
    private func censusRows(
        _ container: SettingsContainer
    ) -> Set<SettingKey> {
        Set(
            SettingKey.allCases.filter {
                $0.placement.area == .general
                    && $0.placement.container == container
            }
        )
    }

    @Test("each container renders exactly its census rows")
    func listsMatchCensus() {
        for (container, order) in GeneralRowOrder.byContainer {
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
                .filter { $0.placement.area == .general }
                .compactMap { $0.placement.container }
        )
        #expect(declared == Set(GeneralRowOrder.byContainer.keys))
    }

    /// `.showMore` is the Advanced drawer's tier and nothing
    /// else's — the two are one decision, and a row that gained
    /// the tier without moving into the drawer would be hidden
    /// with nothing to reveal it.
    @Test("only Advanced holds show-more rows")
    func showMoreIsAdvancedOnly() {
        for key in SettingKey.allCases
        where key.placement.area == .general {
            guard key.placement.tier == .showMore else { continue }
            #expect(
                key.placement.container == .advanced,
                Comment(
                    rawValue:
                        "\(key.id) is .showMore but sits outside "
                        + "the Advanced drawer, so nothing "
                        + "reveals it"
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
            GeneralRowOrder.bespokeContainers
                == Set(GeneralRowOrder.byContainer.keys)
        )
        let root = SourceScan.repoRoot(from: #filePath)
        var files = try SourceScan.swiftSources(
            under: root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/General"
            )
        )
        files += try SourceScan.swiftSources(
            under: root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections"
            )
        ).filter {
            $0.lastPathComponent.hasPrefix("GeneralSection")
        }
        // Assert the scan found its input before asserting about
        // it: an enumerator over a renamed directory yields [] and
        // every check below would pass for having looked at
        // nothing.
        #expect(files.count >= 4)
        for file in files {
            let source = SourceScan.blankingCommentsAndLiterals(
                try String(contentsOf: file, encoding: .utf8)
            )
            let squashed = source.split(
                whereSeparator: \.isWhitespace
            ).joined()
            #expect(
                !squashed.contains("ForEach(GeneralRowOrder."),
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
