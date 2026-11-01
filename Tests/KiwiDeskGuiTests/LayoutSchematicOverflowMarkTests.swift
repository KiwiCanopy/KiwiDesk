import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Stack and Track previews draw the overflow mark the desk draws
/// (#2864, #2235): Core's `OverflowMark.ends` over the preview's
/// own run, each end counting exactly the windows hidden there,
/// placed by Core's `OverflowMark.frame`.
///
/// Main-actor spend: geometry over view fixtures and two small
/// source scans; no AppKit measurement.
@Suite("Schematic overflow mark")
@MainActor
struct LayoutSchematicOverflowMarkTests {
    private let size = CGSize(width: 40, height: 120)

    /// The ends' counts against the run's hidden members, and the
    /// most any one run hid, so a fixture that stopped overflowing
    /// reds rather than passing on nothing.
    private func check(_ laid: SchematicLaidRun?) -> Int {
        guard let laid else { return 0 }
        let hidden = laid.run.count - laid.run.visible.count
        let ends = laid.ends
        #expect(ends.map(\.hidden.count).reduce(0, +) == hidden)
        #expect(ends.isEmpty == (hidden == 0))
        #expect(ends.allSatisfy { laid.run.visible.contains($0.anchor) })
        return hidden
    }

    @Test(
        "a Stack run's marks count every hidden window",
        arguments: [SpawnPlacement.first, .last]
    )
    func stackMarksCount(placement: SpawnPlacement) {
        var most = 0
        for extra in 0...4 {
            let s = StackSchematic(
                masterCount: 1,
                masterRatio: 0.5,
                masterOrientation: .vertical,
                stackPosition: .right,
                placement: placement,
                windows: StackSchematic.shownRows + 1 + extra
            )
            most = max(most, check(s.stackRun(in: size)))
        }
        #expect(most > 0, "no fixture hid a window")
    }

    @Test(
        "a Track run's marks count every hidden window",
        arguments: [SpawnPlacement.first, .last]
    )
    func trackMarksCount(placement: SpawnPlacement) {
        let fits = LayoutSchematic.trackSpillCapacity
        var most = 0
        for windows in 2...(fits + 5) {
            let s = TrackSchematic(
                axis: .vertical,
                newWindow: .ownTrack,
                placement: placement,
                limit: TrackParams.minLimit,
                autoTracks: false,
                windows: windows
            )
            most = max(most, check(s.overflowRun(size)))
        }
        #expect(most > 0, "no fixture hid a window")
    }

    @Test(
        "a full Grid's last track counts every hidden window",
        arguments: [SpawnPlacement.first, .last]
    )
    func gridMarksCount(placement: SpawnPlacement) {
        var most = 0
        for windows in LayoutSchematic.windowCountRange {
            let s = GridSchematic(
                columns: 2,
                rows: 2,
                type: .rigid,
                fillEmptyCells: false,
                autoSize: false,
                splitDirection: .horizontal,
                placement: placement,
                windows: windows
            )
            let cols = s.dims.columns
            let rows = s.dims.rows
            let cells = s.gridCells(size, cols: cols, rows: rows, ids: s.ids)
            let laid = s.gridRun(
                cells: cells,
                cols: cols,
                rows: rows,
                ids: s.ids
            )
            let hidden = check(laid)
            #expect(hidden == s.hiddenCount)
            most = max(most, hidden)
        }
        #expect(most > 0, "no fixture hid a window")
    }

    /// Each run draws Core's marks over its own laid run. Syntax
    /// only: a mount handed another run stays green here.
    @Test(
        "Stack and Track mount the marks",
        arguments: [
            "StackSchematic.swift", "TrackSchematic+Overflow.swift",
            "GridSchematic.swift",
        ]
    )
    func runsMountTheMarks(file: String) throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Layouts/\(file)"
            )
        let source = try SourceScan.strippedSource(at: url)
        #expect(source.occurrences(of: "SchematicOverflowMarks(") == 1)
        #expect(source.occurrences(of: "laid: laid,") == 1)
    }

    /// The marks ask Core's rule and place through Core's frame,
    /// never a reading of their own.
    @Test("The marks ask Core")
    func marksAskCore() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Layouts/"
                    + "SchematicOverflowMarks.swift"
            )
        let source = try SourceScan.strippedSource(at: url)
        #expect(source.occurrences(of: "OverflowMark.ends(of: run") == 1)
        #expect(source.occurrences(of: "OverflowMark.frame(") == 1)
    }
}
