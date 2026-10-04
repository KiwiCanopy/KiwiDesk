import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// #1925: AppKit's `order(_:relativeTo:)` against another app's
/// window looks that window's rights up synchronously first — the
/// last ring cost on a Space switch, up to 390 ms per order while
/// WindowServer was GPU-bound. An ordered-in panel re-stacks in a
/// SkyLight transaction instead; only the first show, and the
/// first after an order-out, goes through AppKit.
@Suite("Border ring re-stack")
@MainActor
struct BorderRestackTests {
    private func render(_ ring: AppKitBorderOverlay) {
        ring.update(
            geometry: BorderGeometry.compute(
                windowFrame: CGRect(x: 0, y: 0, width: 400, height: 300),
                width: 4,
                cornerStyle: .rounded,
                order: .below,
                systemRadius: 10
            ),
            colorHex: "#FF0000",
            screen: nil,
            room: nil
        )
    }

    @Test("The first order is AppKit's; later ones re-stack")
    func reorderSkipsAppKit() {
        let ring = AppKitBorderOverlay(order: .below)
        var restacks: [CGWindowID] = []
        ring.restack = { _, _, target in
            restacks.append(target)
            return true
        }
        render(ring)
        ring.order(relativeTo: 7)
        #expect(restacks.isEmpty)
        #expect(ring.isOrderedIn)
        ring.order(relativeTo: 7)
        ring.order(relativeTo: 7)
        #expect(restacks == [7, 7])
        ring.hide()
        #expect(!ring.isOrderedIn)
        ring.order(relativeTo: 7)
        #expect(restacks == [7, 7])
        #expect(ring.appKitOrders == 2)
    }

    @Test("A missing symbol falls back to AppKit's order")
    func absentSymbolFallsBack() {
        let ring = AppKitBorderOverlay(order: .below)
        var asked = 0
        ring.restack = { _, _, _ in
            asked += 1
            return false
        }
        render(ring)
        ring.order(relativeTo: 7)
        ring.order(relativeTo: 7)
        #expect(asked == 1)
        #expect(ring.appKitOrders == 2)
        #expect(ring.isOrderedIn)
    }
}
