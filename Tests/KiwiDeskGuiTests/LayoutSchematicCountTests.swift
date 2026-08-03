import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The live preview's window count (#678 turn 10).
///
/// The count exists so the schematics *simulate* rather than
/// illustrate — Cascade overflow and Cascade all draw the same
/// frame until the stack is deep enough to overflow, and a track
/// limit means nothing until there are more windows than tracks.
///
/// **These assert each schematic's count-derived arithmetic, not
/// that its source mentions the input.** A first cut scanned for
/// `var windows` and `value: windows`, and guard-prover put a
/// constant in the drawing while leaving both substrings in
/// place: the scan passed on a schematic that had stopped
/// answering the slider. So each derived quantity is internal
/// rather than private, and read here.
/// `@MainActor` because the derived quantities are properties of
/// `View`s, which are main-actor isolated: off the main actor
/// the first read traps in the concurrency runtime rather than
/// failing an expectation, and it does so nondeterministically —
/// it depends which executor swift-testing lands the test on, so
/// the suite passed alone and killed the runner in a full run.
@Suite("Layout preview window count")
@MainActor
struct LayoutSchematicCountTests {
    /// The floor is 2, not 1: at one window every layout draws
    /// the same full-screen rectangle, and several schematics
    /// have no second zone to partition. A change lowering it
    /// reds here, where the reason is written down.
    @Test("the count band starts where a layout differs")
    func countBand() {
        #expect(LayoutSchematic.windowCountRange.lowerBound == 2)
        #expect(
            LayoutSchematic.windowCountRange.contains(
                LayoutSchematic.defaultWindowCount
            )
        )
    }

    /// BSP hands the engine exactly `windows` windows, incoming
    /// tile included — the engine then does the tiling, so this
    /// is the whole of BSP's count contract.
    @Test("BSP tiles the whole count")
    func bspCount() {
        for count in LayoutSchematic.windowCountRange {
            let schematic = BspSchematic(
                splitRatioH: 0.5,
                splitRatioV: 0.5,
                strategy: .longestSide,
                placement: .last,
                windows: count
            )
            #expect(schematic.order.count == count)
        }
    }

    /// Stack partitions the count into the two zones: masters,
    /// the stack run, and the one incoming window. The masters
    /// are clamped so a big master count over few windows still
    /// leaves a stack zone — the two-zone split is the point.
    @Test("Stack partitions the count into its two zones")
    func stackPartition() {
        // Across master counts as well as window counts: at
        // `masterCount: 1` the clamp is inert, so a loop over the
        // band alone leaves it watched by nothing.
        for masterCount in [1, 3, 10] {
            for count in LayoutSchematic.windowCountRange {
                let schematic = stack(
                    masterCount: masterCount,
                    windows: count
                )
                #expect(
                    schematic.masters + schematic.stackWindows + 1
                        == count
                )
                #expect(schematic.masters >= 1)
                // The clamp: masters never outrun the
                // established windows, so the stack zone is on
                // screen at every count.
                #expect(schematic.masters <= max(1, count - 1))
            }
        }
    }

    /// The stack run is what makes the two overflow styles
    /// diverge, so it has to actually deepen with the count —
    /// at every step, not merely between two samples a plateau
    /// could sit inside.
    @Test("a bigger count deepens the stack run")
    func stackDeepens() {
        var previous = -1
        for count in LayoutSchematic.windowCountRange {
            let run = stack(masterCount: 1, windows: count)
                .stackWindows
            #expect(run > previous)
            previous = run
        }
    }

    /// Track opens tracks up to the limit and spills the rest
    /// into the overflow track — which does not exist until
    /// something overflows, and does once the count passes what
    /// the tracks hold.
    @Test("Track fills its tracks before it overflows")
    func trackOverflow() {
        #expect(track(limit: 3, windows: 2).overflowWindows == 0)
        #expect(track(limit: 3, windows: 12).overflowWindows > 0)
        // Tracks never outnumber the windows that open them.
        #expect(track(limit: 4, windows: 2).trackCount == 1)
        #expect(track(limit: 4, windows: 12).trackCount == 4)
        // Auto-tracks is its own ceiling, and the count still
        // bounds it from below.
        #expect(
            track(limit: 9, windows: 12, auto: true).trackCount
                == 3
        )
        // The focused track's own run, read DIRECTLY. Reading it
        // only through `overflowWindows` left it satisfiable by
        // the constant 4 — a focused track drawing four windows
        // over one established one, invisible because the
        // arithmetic happens to land at the sampled shapes
        // (guard-prover, 2026-08-03).
        #expect(track(limit: 3, windows: 2).focusedRun == 1)
        #expect(track(limit: 3, windows: 12).focusedRun == 4)
        for count in LayoutSchematic.windowCountRange {
            let schematic = track(limit: 3, windows: count)
            #expect(schematic.focusedRun >= 1)
            #expect(schematic.focusedRun <= max(1, count - 1))
        }
    }

    /// A dynamic grid balances through the ENGINE's own rule, so
    /// the preview rebalances exactly when KiwiDesk does. Asserted
    /// through the SCHEMATIC, not through `GridLayout.balanced`
    /// directly: an earlier cut called the engine here and let the
    /// schematic reproduce the arithmetic inline, which is the one
    /// thing the schematic's docstring promises it does not do.
    @Test("a dynamic grid balances the way the engine does")
    func gridBalance() {
        // Four windows are a 2×2; a fifth adds a column
        // columns-first, a row rows-first. `windows` counts the
        // incoming tile, so five on screen is `windows: 5`.
        let four = grid(windows: 4, columnsFirst: true)
        #expect(four.ids.count == 4)
        #expect(
            four.dynamicDims.columns == 2
                && four.dynamicDims.rows == 2
        )
        let five = grid(windows: 5, columnsFirst: true)
        #expect(
            five.dynamicDims.columns == 3
                && five.dynamicDims.rows == 2
        )
        let rowsFirst = grid(windows: 5, columnsFirst: false)
        #expect(
            rowsFirst.dynamicDims.columns == 2
                && rowsFirst.dynamicDims.rows == 3
        )
        // And the schematic's dims ARE the engine's, at every
        // count in the band — so an inlined copy that happens to
        // agree at five still reds somewhere.
        for count in LayoutSchematic.windowCountRange {
            let schematic = grid(
                windows: count,
                columnsFirst: true
            )
            let engine = GridLayout.balanced(
                count: schematic.ids.count,
                splitDirection: .horizontal
            )
            #expect(schematic.dynamicDims.columns == engine.columns)
            #expect(schematic.dynamicDims.rows == engine.rows)
        }
    }

    /// Scrolling's row is finite: exactly `windows` slots, with
    /// the focus mid-row so it extends both ways where the count
    /// allows. The follow pair, a second frame of the same
    /// layout, spans the same row.
    @Test("Scrolling draws a finite row of the count")
    func scrollingRow() {
        for count in LayoutSchematic.windowCountRange {
            let schematic = ScrollingSchematic(
                orientation: .horizontal,
                anchor: .center,
                slotSize: .auto,
                placement: .last,
                windows: count
            )
            #expect(schematic.slotIndices.count == count)
            let follow = ScrollingFollowPair(
                orientation: .horizontal,
                slotSize: .auto,
                windows: count
            )
            #expect(follow.slots.count == count)
            // Frame 2 steps the focus to slot 1, so that slot
            // has to exist at every count in the band.
            #expect(follow.slots.contains(1))
        }
    }

    /// Monocle has no fill logic — every window is full-screen —
    /// so the count changes the depth of the fan, capped where
    /// the offsets would march off the canvas.
    @Test("Monocle deepens its fan with the count")
    func monocleFan() {
        #expect(
            MonocleSchematic(orientation: .horizontal, windows: 2)
                .depth == 1
        )
        #expect(
            MonocleSchematic(orientation: .horizontal, windows: 3)
                .depth == 2
        )
        #expect(
            MonocleSchematic(orientation: .horizontal, windows: 12)
                .depth == 3
        )
    }

    /// The scan half: every schematic still *declares* the input.
    /// Kept beside the arithmetic above rather than instead of
    /// it — this is what catches a NEW schematic that never took
    /// the count, which no assertion over existing types can see.
    @Test("every schematic declares the window count")
    func everySchematicDeclaresTheCount() throws {
        let dir = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Layouts"
            )
        var checked = 0
        for file in try SourceScan.swiftSources(under: dir)
        where file.lastPathComponent.hasSuffix("Schematic.swift") {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            checked += 1
            #expect(
                source.contains(
                    "var windows = "
                        + "LayoutSchematic.defaultWindowCount"
                ),
                Comment(
                    rawValue:
                        "\(file.lastPathComponent) declares no "
                        + "window count — the preview's slider "
                        + "would move nothing in it"
                )
            )
        }
        // A floor would let the scan pass having looked at
        // nothing — and a directory rename is exactly how that
        // happens, since the file enumerator yields an empty
        // sequence for a missing path rather than throwing. The
        // tuned layouts are derived; the one rider is Scrolling's
        // follow pair, a second frame of the same layout that
        // needs the count for the same reason.
        #expect(checked == LayoutMode.placementTabs.count + 1)
    }

    // MARK: - Fixtures

    private func stack(
        masterCount: Int,
        windows: Int
    ) -> StackSchematic {
        StackSchematic(
            masterCount: masterCount,
            masterRatio: 0.5,
            overflowStyle: .cascadeOverflow,
            masterOrientation: .vertical,
            stackPosition: .right,
            placement: .last,
            windows: windows
        )
    }

    private func track(
        limit: Int,
        windows: Int,
        auto: Bool = false
    ) -> TrackSchematic {
        TrackSchematic(
            axis: .vertical,
            overflowStyle: .cascadeAll,
            newWindow: .ownTrack,
            placement: .last,
            limit: limit,
            autoTracks: auto,
            windows: windows
        )
    }

    private func grid(
        windows: Int,
        columnsFirst: Bool
    ) -> GridSchematic {
        GridSchematic(
            columns: 2,
            rows: 2,
            type: .dynamic,
            fillEmptySpace: false,
            autoSize: false,
            splitDirection: columnsFirst ? .horizontal : .vertical,
            placement: .last,
            windows: windows
        )
    }
}
