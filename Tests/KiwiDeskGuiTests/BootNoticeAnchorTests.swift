import AppKit
import Testing

@testable import KiwiDesk

/// Where the slow-boot notice sits (#1715): under a visible item,
/// clamped inside the screen, else top-centre below the menu bar;
/// an item in the notch's gap anchors nothing.
@Suite("Slow-boot notice anchor (#1715)")
struct BootNoticeAnchorTests {
    private let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
    private let size = CGSize(width: 300, height: 26)
    private let menuBar: CGFloat = 32

    private var top: CGFloat {
        screen.maxY - menuBar - BootNoticeAnchor.gap - size.height
    }

    @Test("the notice centres under a visible item")
    func centresUnderTheItem() {
        let item = CGRect(x: 1200, y: 1085, width: 30, height: 32)
        let origin = BootNoticeAnchor.origin(
            size: size,
            screen: screen,
            menuBar: menuBar,
            item: item
        )
        #expect(origin == CGPoint(x: 1215 - 150, y: top))
    }

    @Test("an item at either edge keeps the notice inside the screen")
    func clampsAtBothEdges() {
        // A screen right of the primary, so a `width` read for a
        // `maxX` cannot pass.
        let right = screen.offsetBy(dx: 1728, dy: 0)
        let inset = BootNoticeAnchor.inset
        func x(_ itemX: CGFloat) -> CGFloat {
            BootNoticeAnchor.origin(
                size: size,
                screen: right,
                menuBar: menuBar,
                item: CGRect(x: itemX, y: 1085, width: 30, height: 32)
            ).x
        }
        #expect(x(right.maxX - 38) == right.maxX - inset - size.width)
        #expect(x(right.minX + 2) == right.minX + inset)
    }

    @Test("with no item the notice sits top-centre")
    func fallsBackTopCentre() {
        let right = screen.offsetBy(dx: 1728, dy: 0)
        let origin = BootNoticeAnchor.origin(
            size: size,
            screen: right,
            menuBar: menuBar,
            item: nil
        )
        #expect(origin == CGPoint(x: right.midX - 150, y: top))
    }

    @Test("only an item wholly on screen and clear of the notch anchors")
    func notchAndOffScreenAnchorNothing() {
        let gap: ClosedRange<CGFloat> = 771.5...956.5
        func anchors(_ x: CGFloat, notch: Bool = true) -> Bool {
            BootNoticeAnchor.anchors(
                item: CGRect(x: x, y: 1085, width: 30, height: 32),
                screen: screen,
                notchGap: notch ? gap : nil
            )
        }
        #expect(anchors(1200))  // right of the notch
        #expect(anchors(700))  // left of the notch
        #expect(!anchors(800))  // behind it
        #expect(!anchors(760))  // straddling its edge
        #expect(!anchors(1710, notch: false))  // partly off screen
        #expect(!anchors(2000, notch: false))  // off screen
    }
}
