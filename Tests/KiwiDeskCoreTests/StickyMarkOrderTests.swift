import AppKit
import Testing

@testable import KiwiDeskCore

/// A steady sync stacks only a mark that needs it (#2026): every
/// stack against another app's window is a WindowServer round
/// trip, and a sync per switch pass paid one per marked window.
/// The reorder events keep a tracked mark stacked; a settle pass,
/// a mark not yet stacked and an untracked window still order.
@Suite("Sticky mark order", .serialized)
@MainActor
struct StickyMarkOrderTests {
    private func spec(_ id: UInt32) -> StickyMarkManager.Spec {
        StickyMarkManager.Spec(
            window: WindowID(id),
            frame: CGRect(x: 0, y: 0, width: 400, height: 300),
            glass: false
        )
    }

    private func orders(_ manager: StickyMarkManager) -> Int {
        manager.overlays[WindowID(1)]?.orderCount ?? -1
    }

    @Test("a tracked mark is stacked once, then on a settle pass")
    func trackedMarkOrdersOnlyWhenOwed() {
        let manager = StickyMarkManager()
        defer { manager.clear() }
        manager.isWindowServerTracked = { _ in true }

        manager.sync([spec(1)])
        #expect(orders(manager) == 1)
        manager.sync([spec(1)])
        manager.sync([spec(1)])
        #expect(orders(manager) == 1)
        manager.sync([spec(1)], reassertOrder: true)
        #expect(orders(manager) == 2)
    }

    @Test("an untracked mark is stacked on every sync")
    func untrackedMarkOrdersEverySync() {
        let manager = StickyMarkManager()
        defer { manager.clear() }
        manager.isWindowServerTracked = { _ in false }

        manager.sync([spec(1)])
        manager.sync([spec(1)])
        #expect(orders(manager) == 2)
    }

    @Test("a mark brought back on screen is stacked again")
    func reshownMarkOrders() throws {
        let manager = StickyMarkManager()
        defer { manager.clear() }
        manager.isWindowServerTracked = { _ in true }
        manager.sync([spec(1)])
        let mark = try #require(manager.overlays[WindowID(1)])
        #expect(mark.orderCount == 1)

        mark.orderOutForTest()
        manager.sync([spec(1)])

        #expect(mark.orderCount == 2)
    }
}
