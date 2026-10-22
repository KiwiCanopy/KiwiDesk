import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Stack preview's zone asks the engine's run (#2235, gui.md
/// #702): the incoming window takes the focus, so the run shows it
/// wherever it lands, and every other window waits on an edge
/// slot rather than past it.
///
/// Main-actor spend: geometry over a view fixture, no AppKit
/// measurement, no source scan.
@Suite("Stack preview run")
@MainActor
struct LayoutSchematicStackRunTests {
    private let size = CGSize(width: 40, height: 120)

    private func stack(
        windows: Int,
        placement: SpawnPlacement
    ) -> StackSchematic {
        StackSchematic(
            masterCount: 1,
            masterRatio: 0.5,
            masterOrientation: .vertical,
            stackPosition: .right,
            placement: placement,
            windows: windows
        )
    }

    @Test(
        "the incoming window is shown wherever it lands",
        arguments: [SpawnPlacement.first, .last]
    )
    func incomingIsShown(placement: SpawnPlacement) throws {
        let s = stack(
            windows: StackSchematic.shownRows + 4,
            placement: placement
        )
        let slots = s.stackSlots(in: size)
        // `.first` seats the newcomer in the master zone; `.last`
        // at the stack's far end, where the run must reach it.
        if let index = s.stackWins.firstIndex(of: s.newWindow) {
            #expect(!slots[index].hidden)
        } else {
            #expect(placement == .first)
        }
        #expect(slots.filter { !$0.hidden }.count == StackSchematic.shownRows)
    }

    @Test("a hidden window shares an edge slot of the run")
    func hiddenSharesAnEdge() {
        let s = stack(windows: StackSchematic.shownRows + 4, placement: .last)
        let slots = s.stackSlots(in: size)
        let shown = slots.filter { !$0.hidden }.map(\.rect)
        let edges = [shown.first, shown.last].compactMap { $0 }
        #expect(
            slots.filter(\.hidden).allSatisfy { edges.contains($0.rect) }
        )
    }
}
