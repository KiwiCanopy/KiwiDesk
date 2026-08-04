import CoreGraphics
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Where the dashed follows-main tray lands (#678 Phase 3, turn
/// 13b), split from `MonitorArrangementTests` so neither file
/// approaches the size ceiling.
///
/// The tray hangs off the MAIN display rather than sitting in a
/// fixed corner, which is the whole design claim: "follows main"
/// is a statement about that rectangle, so it has to move when
/// the main badge does.
@Suite("Follows-main tray placement")
struct MonitorTrayTests {
    private func display(
        _ id: UInt32,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat = 1500,
        height: CGFloat = 1000
    ) -> Display {
        Display(
            id: DisplayID(id),
            name: "Screen \(id)",
            frame: CGRect(x: x, y: y, width: width, height: height)
        )
    }

    private func layout(
        _ displays: [Display],
        main: UInt32
    ) -> MonitorArrangement.Layout {
        MonitorArrangement.layout(
            displays: displays,
            mainID: DisplayID(main),
            canvas: CGSize(width: 700, height: 240)
        )
    }

    private func card(
        _ result: MonitorArrangement.Layout,
        _ id: UInt32
    ) throws -> CGRect {
        try #require(
            result.displays.first { $0.id == DisplayID(id) }?.rect
        )
    }

    @Test("the tray sits above the main display")
    func aboveByDefault() throws {
        let result = layout(
            [display(1, x: 0, y: 0), display(2, x: 1500, y: 0)],
            main: 1
        )
        let tray = try #require(result.tray)
        let main = try card(result, 1)
        // Above is readable from the rects themselves — which
        // is why the layout carries no separate flag saying so.
        #expect(tray.maxY <= main.minY)
        // Hung off that display, not floated over the picture:
        // the two share a centre line.
        #expect(abs(tray.midX - main.midX) < 0.001)
    }

    /// The tray moves with the badge. Nothing else in the picture
    /// changes, so a tray pinned to a corner would still pass
    /// every other assertion in this file.
    @Test("the tray follows the main badge")
    func followsTheBadge() throws {
        let displays = [display(1, x: 0, y: 0), display(2, x: 1500, y: 0)]
        let first = try #require(layout(displays, main: 1).tray)
        let second = try #require(layout(displays, main: 2).tray)
        #expect(first.midX != second.midX)
    }

    /// Above is only the default. With a display stacked over the
    /// main one — a laptop under a desk display, main on the
    /// laptop — the band above is taken, and a tray drawn there
    /// would land on the other display's card.
    @Test("a taken band puts the tray below")
    func fallsBelowWhenTheBandIsTaken() throws {
        let result = layout(
            [
                display(1, x: 0, y: 0),
                display(2, x: 0, y: -1000),
            ],
            main: 2
        )
        let tray = try #require(result.tray)
        let main = try card(result, 2)
        #expect(tray.minY >= main.maxY)
        for drawn in result.displays {
            #expect(!drawn.rect.intersects(tray))
        }
    }

    /// The picture GROWS to hold the tray rather than the tray
    /// being clipped off the top: everything is normalized back
    /// to a non-negative origin, and the content is what the
    /// scroll view sizes itself to.
    @Test("the picture makes room for the tray")
    func contentHoldsTheTray() throws {
        let result = layout([display(1, x: 0, y: 0)], main: 1)
        let tray = try #require(result.tray)
        #expect(tray.minY >= 0)
        #expect(tray.minX >= 0)
        #expect(result.contentSize.height >= tray.maxY)
        let main = try card(result, 1)
        #expect(main.minY >= 0)
        #expect(
            abs(
                result.contentSize.height
                    - (main.height + tray.height
                        + MonitorArrangement.trayGap)
            ) < 0.001
        )
    }

    /// The whole picture — the tray band included — fits the
    /// canvas it was given.
    ///
    /// The tray is added AFTER the displays are scaled, so
    /// fitting the displays alone overflowed by exactly the band
    /// on every height-bound desk, which is nearly all of them:
    /// one display, two side by side, a laptop under a desk
    /// display. Both of this file's other assertions held while
    /// that shipped (code review, 2026-08-04).
    @Test("the picture fits its canvas, tray and all")
    func contentFitsTheCanvas() throws {
        let canvas = CGSize(width: 700, height: 240)
        for displays in [
            [display(1, x: 0, y: 0, width: 2560, height: 1440)],
            [
                display(1, x: 0, y: 0, width: 2560, height: 1440),
                display(
                    2,
                    x: 2560,
                    y: 0,
                    width: 1512,
                    height: 982
                ),
            ],
            [
                display(1, x: 0, y: 0, width: 2560, height: 1440),
                display(
                    2,
                    x: 500,
                    y: -982,
                    width: 1512,
                    height: 982
                ),
            ],
        ] {
            let result = MonitorArrangement.layout(
                displays: displays,
                mainID: displays[0].id,
                canvas: canvas
            )
            #expect(
                result.contentSize.height <= canvas.height + 0.001,
                Comment(
                    rawValue:
                        "\(displays.count) display(s) overflow "
                        + "the canvas by "
                        + "\(result.contentSize.height - canvas.height)"
                )
            )
        }
    }

    /// A tray narrower than one chip is a drop target nothing
    /// fits in, so it takes the same floor the cards do even when
    /// the display it hangs off is drawn narrower.
    @Test("the tray is never narrower than a card minimum")
    func trayHasTheCardFloor() {
        let anchor = CGRect(x: 0, y: 0, width: 40, height: 40)
        let placed = MonitorTray.rect(
            anchoredTo: anchor,
            avoiding: []
        )
        #expect(
            placed.rect.width
                == MonitorArrangement.minimumCard.width
        )
        #expect(placed.isAbove)
    }
}
