import CoreGraphics
import Testing

@testable import KiwiDesk

/// Simple's docked columns (#2737 ruling 10, re-ruled 2026-10-29):
/// the controls at their cap, a desk sized from the pane, and the
/// pair centred. Pure arithmetic, off the main actor.
@Suite("Simple columns")
struct SimpleColumnsTests {
    private func columns(
        _ width: CGFloat,
        _ height: CGFloat,
        map: Bool = true
    ) -> SimpleColumns {
        SimpleColumns.of(
            CGSize(width: width, height: height),
            drawsMap: map
        )
    }

    /// The parts never take more than the pane, and the margins are
    /// equal, so the pair sits centred.
    private func expectFits(_ c: SimpleColumns, _ width: CGFloat) {
        let used = 2 * c.margin + c.controls + 1 + c.preview
        #expect(used <= width + 0.001)
        #expect(c.margin >= 0)
        #expect(
            c.preview
                == c.plate.width + 2 * SimpleColumns.previewInset
        )
    }

    /// The Open applications row needs the whole cap, so the
    /// controls keep it from the docking width up.
    @Test("the docking width leaves the controls their cap")
    func dockingWidth() {
        let c = columns(SettingsWidthClass.panelBreakpoint, 800)
        #expect(c.controls >= SimpleColumns.contentCap)
        #expect(c.margin == 0)
        #expect(c.plate.width > 300)
        expectFits(c, SettingsWidthClass.panelBreakpoint)
    }

    @Test("a wide window centres the pair")
    func wideCentres() {
        let c = columns(2000, 800)
        #expect(c.controls == SimpleColumns.controls)
        #expect(c.margin > 0)
        let used = 2 * c.margin + c.controls + 1 + c.preview
        #expect(abs(used - 2000) < 0.001)
    }

    @Test("the desk grows with the window, to its cap")
    func deskGrows() {
        let docked = columns(SettingsWidthClass.panelBreakpoint, 800)
        let wide = columns(1600, 800)
        #expect(wide.plate.width > docked.plate.width)
        #expect(wide.barScale > docked.barScale)
        let huge = columns(3000, 2000)
        #expect(huge.plate.width == SimpleColumns.plateCap)
    }

    /// The desk, its chrome and the map fit the pane's height at
    /// every supported size, the map's room only where it draws.
    @Test("the preview fits the pane's height")
    func fitsHeight() {
        for map in [true, false] {
            for width in stride(from: 1200, through: 3200, by: 100) {
                for height in stride(from: 540, through: 1600, by: 60) {
                    let w = CGFloat(width)
                    let h = CGFloat(height)
                    let c = columns(w, h, map: map)
                    let drawn =
                        c.plate.height + SimpleColumns.chromeHeight
                        + (map
                            ? SimpleColumns.spacing
                                + SimpleColumns.mapHeight
                            : 0)
                    #expect(drawn <= h + 0.001)
                    expectFits(c, w)
                }
            }
        }
        // One screen draws no map, so the same pane fits a taller
        // desk.
        #expect(
            columns(1600, 700, map: false).plate.height
                > columns(1600, 700).plate.height
        )
    }

    @Test("the bars keep their tuned scale on the tuned tile")
    func barScale() {
        let tile = SimpleColumns.barScaleTileWidth
        let c = SimpleColumns(
            controls: 0,
            preview: 0,
            margin: 0,
            plate: CGSize(
                width: tile + 2 * SimpleColumns.platePadding,
                height: 0
            )
        )
        #expect(abs(c.barScale - SimpleColumns.barScale) < 0.001)
    }
}
