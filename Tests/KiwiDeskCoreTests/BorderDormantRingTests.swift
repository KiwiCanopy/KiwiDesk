import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// #1925: a Space switch moved every ring of the leaving Space
/// out and built new ones for the arriving one — an `orderOut`,
/// a WindowServer window creation and a re-subscription per
/// switch, each a synchronous round trip that stalls the main
/// actor for hundreds of ms while WindowServer is GPU-bound. A
/// retired ring now goes dormant and comes back for its window.
@Suite("Border dormant rings")
@MainActor
struct BorderDormantRingTests {
    private func spec(_ id: UInt32) -> BorderManager.Spec {
        BorderManager.Spec(
            window: WindowID(id),
            frame: CGRect(x: 0, y: 0, width: 400, height: 300),
            colorHex: "#FF0000",
            width: 4,
            cornerStyle: .rounded
        )
    }

    @Test("A retired ring goes dormant and is the one that returns")
    func retiredRingReturns() {
        let border = BorderManager()
        defer { border.clear() }
        border.sync([spec(1), spec(2)])
        let ring = border.overlays[WindowID(1)]
        border.sync([spec(2)])
        #expect(border.overlays[WindowID(1)] == nil)
        #expect(border.dormant[WindowID(1)] === ring)
        #expect(ring?.isDormant == true)
        border.sync([spec(1), spec(2)])
        #expect(border.overlays[WindowID(1)] === ring)
        #expect(border.dormant[WindowID(1)] == nil)
        #expect(ring?.isDormant == false)
    }

    @Test("A returning ring under animation starts from its spec")
    func returningRingDropsHeldFrame() {
        let border = BorderManager()
        defer { border.clear() }
        let rest = CGRect(x: 0, y: 0, width: 400, height: 300)
        let parked = CGRect(x: 1700, y: 1000, width: 400, height: 300)
        border.sync([spec(1)])
        #expect(border.lastFrame(WindowID(1)) == rest)
        border.sync([])
        // The window comes back from the stash corner while our
        // animation drives it: the ring must ride from there, not
        // flash at the frame it rested at before it left.
        border.isAnimating = { _ in true }
        border.sync([
            BorderManager.Spec(
                window: WindowID(1),
                frame: parked,
                colorHex: "#FF0000",
                width: 4,
                cornerStyle: .rounded
            )
        ])
        #expect(border.lastFrame(WindowID(1)) == parked)
    }

    @Test("A dormant ring fades rather than ordering out")
    func dormantRingFades() throws {
        let border = BorderManager()
        defer { border.clear() }
        border.sync([spec(1)])
        let ring = try #require(border.overlays[WindowID(1)])
        let panel = try #require(ring.backend as? AppKitBorderOverlay)
        #expect(panel.panelAlpha == 1)
        border.sync([])
        #expect(panel.panelAlpha == 0)
        border.sync([spec(1)])
        #expect(panel.panelAlpha == 1)
    }

    @Test("A switch leaves the WindowServer watch set unchanged")
    func watchSetSurvivesSwitch() {
        let border = BorderManager()
        defer { border.clear() }
        border.sync([spec(1), spec(2)])
        let before = border.watchSet(ringed: border.borderedWindows)
        border.sync([spec(3)])
        border.sync([spec(1), spec(2)])
        let after = border.watchSet(ringed: border.borderedWindows)
        #expect(after == before.union([WindowID(3)]))
    }

    @Test("Corner radius outlives dormancy and dies with the window")
    func cornerRadiusLifetime() {
        let border = BorderManager()
        defer { border.clear() }
        border.sync([spec(1)])
        #expect(border.cornerRadii[WindowID(1)] != nil)
        border.sync([])
        #expect(border.cornerRadii[WindowID(1)] != nil)
        border.sync([], alive: [])
        #expect(border.dormant.isEmpty)
        #expect(border.cornerRadii[WindowID(1)] == nil)
    }

    @Test("Production sync names the tracked windows as alive")
    func updateBordersPrunesGoneWindows() {
        let core = makeTestCore()
        core.borders.sync([spec(9)])
        core.borders.sync([])
        #expect(core.borders.dormant[WindowID(9)] != nil)
        core.updateBorders()
        #expect(core.borders.dormant[WindowID(9)] == nil)
    }
}

/// #1925: AppKit pays a WindowServer round trip per order against
/// another app's window, so a steady `sync` stops re-stacking a
/// shown ring and leaves it to the reorder events; the settle
/// passes still re-stack every ring.
@Suite("Border order re-assert")
@MainActor
struct BorderOrderReassertTests {
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
        screen: NSScreen?
    ) {}
    func order(relativeTo windowNumber: CGWindowID) {}
    func hide() {}
}
