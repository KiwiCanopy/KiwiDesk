import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// #1925: AppKit pays a WindowServer round trip per order against
/// another app's window, so a steady `sync` stops re-stacking a
/// shown ring and leaves it to the reorder events; the settle
/// passes still re-stack every ring.
@Suite("Border order re-assert")
@MainActor
struct BorderOrderReassertTests {
    private func spec(_ id: UInt32) -> BorderManager.Spec {
        BorderManager.Spec(
            window: WindowID(id),
            frame: CGRect(x: 0, y: 0, width: 400, height: 300),
            colorHex: "#FF0000",
            width: 4,
            cornerStyle: .rounded
        )
    }

    @Test("A steady sync orders only a ring that is not shown")
    func steadySyncSkipsShownRing() {
        #expect(
            !BorderManager.ordersRing(
                reassert: false,
                needsOrder: false,
                tracked: true
            )
        )
        #expect(
            BorderManager.ordersRing(
                reassert: false,
                needsOrder: true,
                tracked: true
            )
        )
        #expect(
            BorderManager.ordersRing(
                reassert: true,
                needsOrder: false,
                tracked: true
            )
        )
        #expect(
            BorderManager.ordersRing(
                reassert: false,
                needsOrder: false,
                tracked: false
            )
        )
    }

    @Test("A ring needs ordering until shown, and again once hidden")
    func needsOrderLifecycle() {
        let ring = BorderOverlay(window: 7, backend: SilentBackend())
        #expect(ring.needsOrder)
        ring.order(relativeTo: 7)
        #expect(!ring.needsOrder)
        ring.hide()
        #expect(ring.needsOrder)
        ring.order(relativeTo: 7)
        ring.retire()
        #expect(ring.needsOrder)
    }

    @Test("Under tracking a steady sync re-stacks no shown ring")
    func steadySyncOrdersOnlyWhatItMust() {
        let border = BorderManager()
        border.restack = { _, _, _ in false }
        border.moveWindow = { _, _ in false }
        defer { border.clear() }
        var orders = 0
        border.backendFactory = { CountingBackend { orders += 1 } }
        border.watchOverride = { _ in true }
        let both = [spec(1), spec(2)]
        border.sync(both, alive: nil, reassertOrder: false)
        #expect(orders == 2)
        border.sync(both, alive: nil, reassertOrder: false)
        #expect(orders == 2)
        border.sync([spec(1)], alive: nil, reassertOrder: false)
        border.sync(both, alive: nil, reassertOrder: false)
        #expect(orders == 3)
        border.sync(both, alive: nil, reassertOrder: true)
        #expect(orders == 5)
        // The verdict is this sync's: a stream that just failed
        // re-stacks at once rather than one sync late.
        border.watchOverride = { _ in false }
        border.sync(both, alive: nil, reassertOrder: false)
        #expect(orders == 7)
    }

    @Test("A retile syncs steady; both settle passes re-stack")
    func settlePassesReassert() async {
        let core = makeTestCore()
        core.updateBorders()
        #expect(core.borders.lastSyncReassertedOrder == false)
        core.runBorderResync()
        #expect(core.borders.lastSyncReassertedOrder == true)
        core.updateBorders()
        core.scheduleBorderDropReconcile()
        let drop = core.deferred.task(for: .borderDropSettle)
        #expect(drop != nil)
        await drop?.value
        #expect(core.borders.lastSyncReassertedOrder == true)
    }
}

@MainActor
private final class SilentBackend: BorderOverlayBackend {
    let orderMode: BorderGeometry.Order = .below
    func update(
        geometry: BorderGeometry,
        colorHex: String,
        screen: NSScreen?,
        room: CGRect?
    ) {}
    func order(relativeTo windowNumber: CGWindowID) {}
    func hide() {}
}

@MainActor
private final class CountingBackend: BorderOverlayBackend {
    let orderMode: BorderGeometry.Order = .below
    private let onOrder: () -> Void
    init(onOrder: @escaping () -> Void) { self.onOrder = onOrder }
    func update(
        geometry: BorderGeometry,
        colorHex: String,
        screen: NSScreen?,
        room: CGRect?
    ) {}
    func order(relativeTo windowNumber: CGWindowID) { onOrder() }
    func hide() {}
}
