import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

@Suite("App bar manager (per-display)", .serialized)
@MainActor
struct AppBarManagerTests {
    private func bar(
        display: UInt32,
        space: String
    ) -> AppBarManager.Bar {
        AppBarManager.Bar(
            display: DisplayID(display),
            space: SpaceID(space),
            items: [
                AppBarOverlay.Item(
                    id: WindowID(1),
                    name: "A",
                    icon: nil
                )
            ],
            activeIndex: 0,
            strip: CGRect(x: 0, y: 0, width: 100, height: 32),
            style: AppBarStyle()
        )
    }

    @Test("sync tracks one shown bar per display")
    func syncTracksDisplays() {
        let manager = AppBarManager()
        manager.sync([
            bar(display: 1, space: "1"),
            bar(display: 2, space: "web"),
        ])
        #expect(
            manager.shownDisplays == [DisplayID(1), DisplayID(2)]
        )
    }

    @Test("a display dropped from sync stops showing its bar")
    func dropRetiresDisplay() {
        let manager = AppBarManager()
        manager.sync([
            bar(display: 1, space: "1"),
            bar(display: 2, space: "web"),
        ])
        manager.sync([bar(display: 1, space: "1")])
        #expect(manager.shownDisplays == [DisplayID(1)])
    }

    @Test("hideAll retires every bar")
    func hideAllClears() {
        let manager = AppBarManager()
        manager.sync([bar(display: 1, space: "1")])
        manager.hideAll()
        #expect(manager.shownDisplays.isEmpty)
    }

    @Test("a drag routes to the bar's own space")
    func moveRoutesToSpace() {
        let manager = AppBarManager()
        var moved: (SpaceID, Int, Int)?
        manager.onMove = { space, from, to in
            moved = (space, from, to)
        }
        // Two displays showing different spaces; the reorder
        // hook must carry the space of the dragged display, not
        // a global active one.
        manager.sync([
            bar(display: 1, space: "1"),
            bar(display: 2, space: "web"),
        ])
        manager.overlayForTesting(DisplayID(2))?.onMove(0, 3)
        #expect(moved?.0 == SpaceID("web"))
        #expect(moved?.1 == 0)
        #expect(moved?.2 == 3)
    }
}
