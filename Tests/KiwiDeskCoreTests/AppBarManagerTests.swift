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
            style: AppBarStyle(),
            edge: .top
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

    @Test("syncing an empty set retires every bar")
    func emptySyncClears() {
        let manager = AppBarManager()
        manager.sync([bar(display: 1, space: "1")])
        manager.sync([])
        #expect(manager.shownDisplays.isEmpty)
    }

    @Test("a degenerate strip retires rather than claims a bar")
    func degenerateStripNotShown() {
        let manager = AppBarManager()
        let empty = AppBarManager.Bar(
            display: DisplayID(1),
            space: SpaceID("1"),
            items: [],
            activeIndex: nil,
            strip: .zero,
            style: AppBarStyle(),
            edge: .top
        )
        manager.sync([empty])
        #expect(manager.shownDisplays.isEmpty)
    }

    private func bar(
        display: UInt32,
        space: String,
        edge: AppBarEdge,
        strip: CGRect
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
            strip: strip,
            style: AppBarStyle(),
            edge: edge
        )
    }

    @Test("topStrip returns the painted top strip for a space")
    func topStripForSpace() {
        let manager = AppBarManager()
        let strip = CGRect(x: 0, y: 10, width: 1920, height: 32)
        manager.sync([
            bar(display: 1, space: "1", edge: .top, strip: strip)
        ])
        #expect(manager.topStrip(forSpace: SpaceID("1")) == strip)
    }

    @Test("topStrip ignores non-top bars")
    func topStripIgnoresOtherEdges() {
        let manager = AppBarManager()
        manager.sync([
            bar(
                display: 1,
                space: "1",
                edge: .left,
                strip: CGRect(x: 0, y: 0, width: 32, height: 1080)
            )
        ])
        #expect(manager.topStrip(forSpace: SpaceID("1")) == nil)
    }

    @Test("topStrip is nil for a space showing no bar")
    func topStripNilWhenUnpainted() {
        let manager = AppBarManager()
        manager.sync([
            bar(
                display: 1,
                space: "1",
                edge: .top,
                strip: CGRect(x: 0, y: 10, width: 1920, height: 32)
            )
        ])
        // A space with no synced bar (only floats, or bar off).
        #expect(manager.topStrip(forSpace: SpaceID("other")) == nil)
    }

    @Test("shownTopStrips spans all displays' top bars")
    func shownTopStripsMultiDisplay() {
        let manager = AppBarManager()
        let a = CGRect(x: 0, y: 10, width: 1920, height: 32)
        let b = CGRect(x: 0, y: 10, width: 1440, height: 24)
        manager.sync([
            bar(display: 1, space: "1", edge: .top, strip: a),
            bar(display: 2, space: "web", edge: .top, strip: b),
        ])
        let spaces = Set(manager.shownTopStrips.map(\.space))
        #expect(spaces == [SpaceID("1"), SpaceID("web")])
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
