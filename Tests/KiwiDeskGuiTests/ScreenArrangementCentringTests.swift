import CoreGraphics
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Where the Screens picture sits in its container, and the tray
/// band that the #2065 padding moved under (#2065). Arithmetic on
/// derived rectangles, as `ScreenArrangementTests` argues.
@Suite("Screens picture centring and tray band (#2065)")
struct ScreenArrangementCentringTests {
    private let canvas = CGSize(width: 600, height: 200)

    private func display(
        _ id: UInt32,
        x: CGFloat,
        width: CGFloat,
        height: CGFloat
    ) -> Display {
        Display(
            id: DisplayID(id),
            name: "Screen \(id)",
            frame: CGRect(x: x, y: 0, width: width, height: height)
        )
    }

    /// The drawn bounding box — screens and tray — moved to where
    /// the picture places it.
    private func placedBox(
        _ displays: [Display],
        main: DisplayID?
    ) -> CGRect {
        let layout = ScreenArrangement.layout(
            displays: displays,
            mainID: main,
            canvas: canvas
        )
        let origin = ScreenArrangement.origin(
            of: layout.contentSize,
            in: canvas
        )
        let box = ScreenArrangement.union(
            layout.displays.map(\.rect)
                + [layout.tray].compactMap { $0 }
        )
        return box.offsetBy(dx: origin.x, dy: origin.y)
    }

    @Test("a single screen is centred in its container")
    func singleScreenIsCentred() {
        let box = placedBox(
            [display(1, x: 0, width: 1512, height: 982)],
            main: nil
        )
        #expect(abs(box.midX - canvas.width / 2) < 0.5)
        #expect(abs(box.midY - canvas.height / 2) < 0.5)
        #expect(box.minX > 1)
    }

    @Test("the bounding box is centred, tray and all")
    func boundingBoxIsCentred() {
        let left = display(1, x: 0, width: 1512, height: 982)
        let right = display(2, x: 1512, width: 2560, height: 1440)
        for main in [nil, left.id, right.id] {
            let box = placedBox([left, right], main: main)
            #expect(abs(box.midX - canvas.width / 2) < 0.5)
            #expect(abs(box.midY - canvas.height / 2) < 0.5)
        }
    }

    @Test("an axis that overflows scrolls from the origin")
    func overflowingAxisStaysAtTheOrigin() {
        let origin = ScreenArrangement.origin(
            of: CGSize(width: 900, height: 120),
            in: canvas
        )
        #expect(origin.x == 0)
        #expect(origin.y == 40)
    }

    /// The tray band holds exactly the rows it reserved: the card
    /// padding moved under a hand-typed band once, and `split`
    /// then counted a row fewer than the band was grown for
    /// (#2065 review).
    @Test("the tray band holds the rows it reserves")
    func trayBandHoldsItsRows() {
        let step =
            ScreenCardChips.chipHeight + ScreenCardChips.spacing
        for width in [120.0, 260.0, 600.0] {
            for chips in 0...24 {
                let band = ScreenArrangement.trayHeight(
                    chips: chips,
                    width: width
                )
                let reserved =
                    Int(
                        ((band - ScreenArrangement.trayHeight) / step)
                            .rounded()
                    ) + 1
                let held = ScreenCardChips.rows(
                    in: CGSize(width: width, height: band),
                    header: ScreenCardChips.trayHeaderHeight
                )
                #expect(
                    held == reserved,
                    "\(chips) chips at \(width) pt"
                )
            }
        }
    }
}
