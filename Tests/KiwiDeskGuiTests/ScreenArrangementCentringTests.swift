import CoreGraphics
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Where the Screens picture sits in its container (#2065).
/// Arithmetic on derived rectangles, as `ScreenArrangementTests`
/// argues.
@Suite("Screens picture centring (#2065)")
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
}
