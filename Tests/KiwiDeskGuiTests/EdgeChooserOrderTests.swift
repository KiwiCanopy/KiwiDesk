import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Every edge chooser reads Left · Top · Bottom · Right (owner,
/// 2026-10-29, #2766), and each one takes its order from the one
/// list rather than the enum's case order. Off the main actor save
/// the list reads: the case-order clause scans the GUI tree.
@Suite("Edge choosers share one order")
struct EdgeChooserOrderTests {
    private static let order = ["left", "top", "bottom", "right"]

    @Test("both lists read left, top, bottom, right")
    @MainActor
    func listsAgree() {
        #expect(AppBarOptions.edgeOrder.map(\.rawValue) == Self.order)
        #expect(
            StackPositionOptions.order.map(\.rawValue) == Self.order
        )
        #expect(AppBarOptions.edge.map(\.0) == AppBarOptions.edgeOrder)
        #expect(
            StackPositionOptions.all.map(\.0)
                == StackPositionOptions.order
        )
    }

    @Test("each list offers every case")
    func listsAreWhole() {
        #expect(
            Set(AppBarOptions.edgeOrder) == Set(AppBarEdge.allCases)
        )
        #expect(
            Set(StackPositionOptions.order)
                == Set(StackParams.StackPosition.allCases)
        )
    }

    @Test(
        "every chooser reads the list",
        arguments: [
            (
                "Settings/Components/Layouts/LayoutCard+Rows.swift",
                "options: StackPositionOptions.all.map"
            ),
            (
                "Settings/Components/SpaceOverrides/"
                    + "SpaceOverrideRows+StackRows.swift",
                "options: StackPositionOptions.all,"
            ),
            (
                "Settings/Components/Bars/KiwiShelfCard+Edge.swift",
                "AppBarOptions.edge.map"
            ),
            (
                "Settings/Components/Keybindings/PocketGroup.swift",
                "ForEach(AppBarOptions.edgeOrder,"
            ),
        ]
    )
    func choosersReadTheList(file: String, needle: String) throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/" + file)
        let source = try SourceScan.strippedSource(at: url)
        #expect(source.contains(needle), "\(file)")
    }

    /// A chooser walking an edge enum's cases shows its stored
    /// order, so the GUI tree spells neither `allCases` at all.
    @Test("no GUI file walks an edge enum's cases")
    func noCaseOrderInTheGui() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let files = try SourceScan.swiftSources(under: root)
        #expect(files.count > 100, "scan found \(files.count) files")
        for file in files {
            let source = try SourceScan.strippedSource(at: file)
            for needle in [
                "AppBarEdge.allCases", "StackPosition.allCases",
            ] {
                #expect(
                    !source.contains(needle),
                    "\(file.lastPathComponent): \(needle)"
                )
            }
        }
    }
}
