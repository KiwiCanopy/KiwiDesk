import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Stack preview draws every master and no "+N" on the master
/// zone (#2891): the desk never hides a master, and the chip is the
/// overflow mark's glyph alone.
@Suite("Stack preview master zone")
@MainActor
struct StackMasterZoneTests {
    private func stack(masters: Int, windows: Int) -> StackSchematic {
        StackSchematic(
            masterCount: masters,
            masterRatio: 0.5,
            masterOrientation: .vertical,
            stackPosition: .right,
            placement: .last,
            windows: windows
        )
    }

    @Test("Every master draws, up to the control's ten")
    func everyMasterDraws() {
        for masters in [1, 4, 5, 10] {
            let zone = stack(masters: masters, windows: 12)
            #expect(zone.masterDisplay.count == masters)
        }
    }

    /// The zone's floor is 6 pt (`masterSpan`); its gaps never eat
    /// the whole span, so no tile collapses at any count.
    @Test("A crowded zone keeps every tile a positive size")
    func gapsLeaveRoom() {
        for span: CGFloat in [6, 84, 240] {
            for count in 1...10 {
                let gap = StackSchematic.masterGap(along: span, count: count)
                let tile = (span - gap * CGFloat(count - 1)) / CGFloat(count)
                #expect(gap > 0 && tile > 0, "span \(span), \(count)")
                #expect(gap <= StackSchematic.zoneGap)
            }
        }
    }

    @Test("Only the overflow marks build the +N chip")
    func chipHasOneBuilder() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let files = try SourceScan.swiftSources(under: root)
        #expect(!files.isEmpty)
        let builders = try files.filter {
            try SourceScan.strippedSource(at: $0)
                .contains("SchematicMoreChip(")
        }.map(\.lastPathComponent)
        #expect(builders == ["SchematicOverflowMarks.swift"])
    }
}
