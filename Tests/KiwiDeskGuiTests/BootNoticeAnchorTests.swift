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

    @Test("an item at the edge keeps the notice inside the screen")
    func clampsAtTheEdge() {
        let item = CGRect(x: 1690, y: 1085, width: 30, height: 32)
        let origin = BootNoticeAnchor.origin(
            size: size,
            screen: screen,
            menuBar: menuBar,
            item: item
        )
        let inset = BootNoticeAnchor.inset
        #expect(origin.x == screen.maxX - inset - size.width)
    }

    @Test("with no item the notice sits top-centre")
    func fallsBackTopCentre() {
        let origin = BootNoticeAnchor.origin(
            size: size,
            screen: screen,
            menuBar: menuBar,
            item: nil
        )
        #expect(origin == CGPoint(x: screen.midX - 150, y: top))
    }

    @Test("an item in the notch gap or off screen anchors nothing")
    func notchAndOffScreenAnchorNothing() {
        let gap: ClosedRange<CGFloat> = 771.5...956.5
        let beside = CGRect(x: 1200, y: 1085, width: 30, height: 32)
        let behind = CGRect(x: 800, y: 1085, width: 30, height: 32)
        let away = CGRect(x: 2000, y: 1085, width: 30, height: 32)
        #expect(
            BootNoticeAnchor.anchors(
                item: beside,
                screen: screen,
                notchGap: gap
            )
        )
        #expect(
            !BootNoticeAnchor.anchors(
                item: behind,
                screen: screen,
                notchGap: gap
            )
        )
        #expect(
            !BootNoticeAnchor.anchors(
                item: away,
                screen: screen,
                notchGap: nil
            )
        )
    }
}
