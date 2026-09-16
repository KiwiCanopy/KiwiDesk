import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Scrolling preview draws a share the way the engine
/// resolves it (#1382): a fraction is a share of the pitch, so
/// two 50% slots plus their gap span the screen exactly. Asked
/// of the schematic's arithmetic, not of a source scan (gui.md).
@Suite("Layout preview pitch share (#1382)")
@MainActor
struct LayoutSchematicPitchTests {
    @Test("two 50% slots fill the drawn screen, gap included")
    func halfIsTwoColumns() {
        let schematic = ScrollingSchematic(
            orientation: .horizontal,
            anchor: .start,
            slotSize: .fraction(0.5),
            placement: .last,
            windows: 3,
            scale: .panel
        )
        let m = schematic.metrics(along: 600)
        #expect(
            abs(m.slot * 2 + ScrollingSchematic.slotGap - m.screenLen) < 0.01
        )
        // And the engine's own answer, not a local copy of it.
        let engine = ScrollSize.fraction(0.5).resolved(
            along: m.screenLen,
            gap: ScrollingSchematic.slotGap,
            horizontal: true
        )
        #expect(abs(m.slot - engine) < 0.01)
    }
}
