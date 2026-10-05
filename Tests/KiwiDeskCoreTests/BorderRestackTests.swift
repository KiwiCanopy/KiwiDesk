import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// #1962: WindowServer applies no SkyLight order to an AppKit
/// panel — `SLSTransactionOrderWindow`, `SLSOrderWindow` and the
/// group order with a plain commit all left a probe panel where it
/// was (macOS 27.0.1, 2026-10-05), so #1925's re-stack never moved
/// a ring. Every order of an ordered-in ring therefore goes through
/// AppKit, whose order commits through the bridge. That the order
/// MOVES the panel is `BorderStackingTests` ▸ `reorderMovesTheRing`;
/// which sites may order is `BorderOrderCensusTests`.
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

    @Test("every order of a ring goes through AppKit")
    func everyOrderIsAppKits() {
        let ring = AppKitBorderOverlay(
            order: .below,
            movePanel: { _, _ in false }
        )
        render(ring)
        ring.order(relativeTo: 7)
        #expect(ring.isOrderedIn)
        ring.order(relativeTo: 7)
        ring.order(relativeTo: 8)
        #expect(ring.appKitOrders == 3)
        ring.hide()
        #expect(!ring.isOrderedIn)
        ring.order(relativeTo: 7)
        #expect(ring.appKitOrders == 4)
    }
}
