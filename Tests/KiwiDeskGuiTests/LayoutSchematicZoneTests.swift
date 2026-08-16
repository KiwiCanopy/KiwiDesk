import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Which windows the Stack preview draws in which zone (#707).
///
/// Two guards already read this schematic and neither watches the
/// partition. `LayoutSchematicCountTests.stackPartition` pins the
/// zone SIZES — `masters + stackWindows + 1 == count`, and the
/// masters clamp. `LayoutSchematicPlacementTests.stackPlacement`
/// pins the flat array ORDER, where the incoming `+` splices in.
/// Between them sits the thing a reader actually takes off the
/// frame: which of those windows land on the master side. Swap
/// both zone reads — `order.prefix(masters)` → `.suffix`,
/// `order.dropFirst(masters)` → `.dropLast` — and the preview
/// draws the LAST N windows as the master zone with the whole
/// suite green.
///
/// **These ask the engine rather than restate it.**
/// `StackLayout.partition` is the boundary rule itself (the first
/// `masterCount` windows are the master zone), so the assertion
/// is the schematic's zones against the engine's own split of the
/// schematic's own array — a copy of the rule written here would
/// drift on the day the rule moved, which is the failure gui.md's
/// "a preview that claims engine behaviour asks the engine" names.
///
/// Split from both suites above rather than added to either: each
/// is within twenty lines of the §2.1 file ceiling.
///
/// `@MainActor` because the zone reads are properties of a `View`,
/// which is main-actor isolated: off the main actor the first read
/// traps in the concurrency runtime rather than failing an
/// expectation, and it does so nondeterministically — it depends
/// which executor swift-testing lands the test on.
@Suite("Layout preview zone partition")
@MainActor
struct LayoutSchematicZoneTests {
    /// Every placement, so a splice that lands the incoming window
    /// inside the master run is partitioned like any other array
    /// rather than special-cased.
    private let placements: [SpawnPlacement] = [
        .first, .last, .beforeFocused, .afterFocused,
    ]

    /// `StackParams.StackPosition` is not `CaseIterable`, so the
    /// four are listed — a fifth position would need adding here,
    /// which is the same obligation every other sweep over this
    /// enum in the suite already carries.
    private let positions: [StackParams.StackPosition] = [
        .top, .right, .bottom, .left,
    ]

    private func stack(
        masterCount: Int,
        windows: Int,
        placement: SpawnPlacement = .afterFocused,
        masterOrientation: StackParams.Orientation = .vertical,
        stackPosition: StackParams.StackPosition = .right
    ) -> StackSchematic {
        StackSchematic(
            masterCount: masterCount,
            masterRatio: 0.5,
            overflowStyle: .cascadeOverflow,
            masterOrientation: masterOrientation,
            stackPosition: stackPosition,
            placement: placement,
            windows: windows
        )
    }

    /// The partition itself. Across master counts as well as
    /// window counts, for the same reason the sibling suites
    /// sweep both: at `masterCount: 1` the clamp is inert, so a
    /// loop over the band alone leaves it watched by nothing.
    @Test("the two zones are the engine's partition of the array")
    func zonesAreTheEnginesPartition() {
        for placement in placements {
            for masterCount in [1, 3, 10] {
                for count in LayoutSchematic.windowCountRange {
                    let schematic = stack(
                        masterCount: masterCount,
                        windows: count,
                        placement: placement
                    )
                    let split = StackLayout.partition(
                        schematic.order,
                        masterCount: schematic.masters
                    )
                    let what =
                        "\(masterCount)m at \(count), "
                        + "\(placement)"
                    #expect(
                        schematic.masterWins
                            == Array(split.master),
                        Comment(
                            rawValue:
                                "master zone disagrees with "
                                + "StackLayout.partition — \(what)"
                        )
                    )
                    #expect(
                        schematic.stackWins
                            == Array(split.stack ?? []),
                        Comment(
                            rawValue:
                                "stack zone disagrees with "
                                + "StackLayout.partition — \(what)"
                        )
                    )
                }
            }
        }
    }

    /// The clamp's whole purpose, stated as membership rather than
    /// as a count: however big the master count, the stack zone
    /// still holds a window, so the two-zone split is on screen at
    /// every count the slider can reach. `stackPartition` says the
    /// same thing in sizes; this says it about the array the frame
    /// is drawn from, which is what `.dropLast` would have kept
    /// satisfying while emptying the wrong end.
    @Test("the stack zone is never empty, at any master count")
    func stackZoneSurvivesTheClamp() {
        for masterCount in [1, 3, 10] {
            for count in LayoutSchematic.windowCountRange {
                let schematic = stack(
                    masterCount: masterCount,
                    windows: count
                )
                #expect(!schematic.stackWins.isEmpty)
                // And the two zones between them are the whole
                // array, with nothing drawn twice — a partition,
                // not two independent reads that happen to agree
                // on their lengths.
                #expect(
                    schematic.masterWins + schematic.stackWins
                        == schematic.order
                )
            }
        }
    }

    /// #313's mirror, which the preview's docstring promises
    /// ("never lies about where the boundary master sits when the
    /// stack leads") and which nothing held it to.
    ///
    /// Asserted two ways on purpose. The first is the engine's
    /// own verdict, so a schematic that stops consulting
    /// `mirrorsMasterZone` — or that swaps the ternary's arms —
    /// reds. The second is what a reader takes off the frame: the
    /// master drawn nearest the seam. The engine agreement alone
    /// would pass on a reversal applied in the wrong direction if
    /// the rule and the reversal were ever inverted together.
    @Test("the master zone mirrors exactly when the engine does")
    func masterZoneMirrorsWithTheEngine() {
        for position in positions {
            for orientation in [
                StackParams.Orientation.horizontal, .vertical,
            ] {
                let schematic = stack(
                    masterCount: 3,
                    windows: 8,
                    masterOrientation: orientation,
                    stackPosition: position
                )
                var params = StackParams()
                params.masterOrientation = orientation
                params.stackPosition = position
                let mirrors = StackLayout.mirrorsMasterZone(params)
                let what = "\(position)/\(orientation)"
                #expect(
                    schematic.masterDisplay
                        == (mirrors
                            ? schematic.masterWins.reversed()
                            : schematic.masterWins),
                    Comment(
                        rawValue:
                            "render order disagrees with "
                            + "StackLayout.mirrorsMasterZone — "
                            + what
                    )
                )
                // The consequence, in the docstring's own terms:
                // mirrored, the master at the stack seam is the
                // LAST one in array order rather than the first.
                #expect(
                    schematic.masterDisplay.first
                        == (mirrors
                            ? schematic.masterWins.last
                            : schematic.masterWins.first),
                    Comment(
                        rawValue:
                            "the boundary master is not at the "
                            + "seam — \(what)"
                    )
                )
            }
        }
    }
}
