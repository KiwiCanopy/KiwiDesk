import CoreGraphics
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// **A laid-out arrangement fits the canvas it was given.**
///
/// The defect had two halves, both concessions to being
/// droppable on, and both applied to a canvas that hosts no
/// chips at all. The tray's band (`trayHeight` + `trayGap`, 62)
/// was reserved from a 56 pt canvas, so the subtraction clamped
/// to 1 pt; and the minimum-card floor then beat the fit
/// outright, so the displays were drawn at chip-holding size
/// regardless of the canvas. The floor is the dominant half —
/// removing only the band still overflowed by 135 pt into 56.
/// It shipped as a display rectangle drawn outside its own Home
/// card and across the subtitle beneath it.
///
/// Guarded by **arithmetic over the returned rects**, never by a
/// scan for the parameter: a scan would pass the moment someone
/// passed the flag and still mis-sized the canvas, and it is the
/// geometry that was wrong. The tall canvases are here so the fix
/// cannot be "always subtract nothing" — the band still has to be
/// reserved where a tray is actually drawn.
@Suite("Monitor arrangement fits its canvas")
struct MonitorArrangementFitTests {
    private func display(
        _ id: UInt32,
        _ frame: CGRect
    ) -> Display {
        Display(
            id: DisplayID(id),
            name: "D\(id)",
            frame: frame
        )
    }

    /// One 16:10 display, the single-display desk the Home card
    /// draws for most users.
    private var single: [Display] {
        [display(1, CGRect(x: 0, y: 0, width: 2560, height: 1600))]
    }

    /// A laptop under a desk display — the height-bound shape the
    /// tray reservation exists for.
    private var stacked: [Display] {
        [
            display(1, CGRect(x: 0, y: 0, width: 2560, height: 1440)),
            display(2, CGRect(x: 300, y: 1440, width: 1440, height: 900)),
        ]
    }

    /// The Home card's own thumbnail size: the desktop plate's
    /// interior at the grid's minimum card width (#786 —
    /// `SettingsTheme.plateHeight` minus the Monitors tile's
    /// 8 pt padding on each side, inside a 240 pt card). Still
    /// SHORTER than `trayHeight + trayGap`, which is the case
    /// that broke.
    private let cardCanvas = CGSize(
        width: 240 - 16,
        height: SettingsTheme.plateHeight - 16
    )

    @Test("a chip-less canvas holds every display")
    func chipLessFitsTheCanvas() {
        for displays in [single, stacked] {
            let layout = MonitorArrangement.layout(
                displays: displays,
                mainID: DisplayID(1),
                canvas: cardCanvas,
                hostsChips: false
            )
            #expect(!layout.displays.isEmpty)
            for drawn in layout.displays {
                #expect(
                    drawn.rect.maxX <= cardCanvas.width + 0.5,
                    "a display overflows the canvas horizontally"
                )
                #expect(
                    drawn.rect.maxY <= cardCanvas.height + 0.5,
                    "a display overflows the canvas vertically"
                )
                #expect(drawn.rect.minX >= -0.5)
                #expect(drawn.rect.minY >= -0.5)
            }
        }
    }

    /// The band is still reserved where a tray IS drawn, so the
    /// fix cannot be "stop subtracting". Asserted on a canvas
    /// tall enough for one, since the short-canvas case has no
    /// room for a tray at all.
    @Test("a tray canvas leaves room for the tray")
    func trayCanvasReservesTheBand() {
        let canvas = CGSize(width: 420, height: 300)
        let layout = MonitorArrangement.layout(
            displays: single,
            mainID: DisplayID(1),
            canvas: canvas
        )
        let tray = try? #require(layout.tray)
        #expect(tray != nil)
        for drawn in layout.displays {
            #expect(drawn.rect.maxY <= canvas.height + 0.5)
        }
        if let tray {
            #expect(
                tray.maxY <= canvas.height + 0.5,
                "the tray itself must fit the canvas"
            )
        }
    }

    /// An ordinary desk must not make the picture SCROLL.
    ///
    /// `layout` fills the canvas it is handed almost exactly — it
    /// fits the displays into `canvas − trayHeight − trayGap` and
    /// then puts the band back — so `contentSize` lands on the
    /// canvas height, and any padding the view adds afterwards
    /// pushes it past the frame. That is what scrolled a
    /// one-display desk by a few points.
    ///
    /// Asserted against the canvas `MonitorsPicture` actually
    /// hands over (its 240 pt band less its 4 pt inset either
    /// side), so the test fails if either constant moves without
    /// the other.
    @Test("a one-display desk fits without scrolling")
    func oneDisplayDoesNotScroll() {
        let inset: CGFloat = 4
        let canvas = CGSize(
            width: 520 - inset * 2,
            height: 240 - inset * 2
        )
        let layout = MonitorArrangement.layout(
            displays: single,
            mainID: DisplayID(1),
            canvas: canvas
        )
        #expect(
            layout.contentSize.height <= canvas.height + 0.5,
            "the picture would scroll vertically on one display"
        )
        #expect(
            layout.contentSize.width <= canvas.width + 0.5,
            "the picture would scroll horizontally"
        )
    }

    /// The two arms differ, which is what says `hostsChips` is
    /// read at all: on one canvas the tray-less fit must be
    /// strictly the taller of the two, because it has the band
    /// back. Without this a defaulted-true parameter that nothing
    /// consulted would pass both tests above.
    @Test("reserving the band changes the fit")
    func theFlagIsLoadBearing() {
        let canvas = CGSize(width: 420, height: 300)
        let reserved = MonitorArrangement.layout(
            displays: single,
            mainID: DisplayID(1),
            canvas: canvas
        )
        let bare = MonitorArrangement.layout(
            displays: single,
            mainID: DisplayID(1),
            canvas: canvas,
            hostsChips: false
        )
        let reservedHeight = reserved.displays.first?.rect.height
        let bareHeight = bare.displays.first?.rect.height
        #expect(reservedHeight != nil && bareHeight != nil)
        if let reservedHeight, let bareHeight {
            #expect(
                bareHeight > reservedHeight,
                "the tray-less fit should use the band back"
            )
        }
        #expect(bare.tray == nil)
    }

    /// The tray grows with what it holds.
    ///
    /// It was a constant 52 pt — one chip row — so a fourth space
    /// following main wrapped onto a second row that the box did
    /// not have, and the tray's own heading was pushed out of the
    /// top of it. Asserted as a STRICT increase against the
    /// one-row height rather than against a copied number, so the
    /// row arithmetic can be retuned without editing this.
    @Test("the tray box grows with a second row of chips")
    func trayGrowsWithItsChips() {
        // Narrow enough that three chips cannot share a row.
        let width: CGFloat = 120
        let one = MonitorArrangement.trayHeight(
            chips: 1,
            width: width
        )
        #expect(one == MonitorArrangement.trayHeight)
        let many = MonitorArrangement.trayHeight(
            chips: 6,
            width: width
        )
        #expect(
            many > one,
            "six chips at 120 pt need more than one row"
        )
        // And a wide tray does NOT grow for the same count —
        // otherwise the derivation is counting chips and
        // ignoring the width it has to fit them in.
        #expect(
            MonitorArrangement.trayHeight(chips: 6, width: 1200)
                < many
        )
    }
}
