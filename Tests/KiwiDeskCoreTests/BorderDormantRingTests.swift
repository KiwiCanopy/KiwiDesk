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
        border.movePanel = { _, _ in false }
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
        border.movePanel = { _, _ in false }
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
        border.movePanel = { _, _ in false }
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

    @Test("A switch leaves the WindowServer request unchanged")
    func watchRequestSurvivesSwitch() {
        let border = BorderManager()
        border.movePanel = { _, _ in false }
        defer { border.clear() }
        var requests: [Set<WindowID>] = []
        border.watchOverride = {
            requests.append($0)
            return true
        }
        border.sync([spec(1), spec(2)])
        border.sync([spec(3)])
        border.sync([spec(1), spec(2)])
        let all: Set<WindowID> = [WindowID(1), WindowID(2), WindowID(3)]
        #expect(requests == [[WindowID(1), WindowID(2)], all, all])
    }

    @Test("Corner radius outlives dormancy and dies with the window")
    func cornerRadiusLifetime() {
        let border = BorderManager()
        border.movePanel = { _, _ in false }
        defer { border.clear() }
        border.sync([spec(1)])
        #expect(border.cornerRadii[WindowID(1)] != nil)
        border.sync([])
        #expect(border.cornerRadii[WindowID(1)] != nil)
        border.sync([], alive: [], reassertOrder: true)
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

    @Test("Borders off release every dormant ring")
    func disabledBordersReleasePool() {
        let core = makeTestCore()
        core.borders.sync([spec(9), spec(4)])
        core.borders.sync([])
        core.state.windows.upsert(
            ManagedWindow(id: WindowID(4), pid: 4, appName: "Here")
        )
        core.state.awayWindows[WindowID(9)] = AwayWindow(
            id: WindowID(9),
            pid: 1,
            appName: "App",
            appBundleID: nil,
            nativeSpace: 1,
            isUp: true
        )
        core.updateBorders()
        #expect(core.borders.dormant[WindowID(9)] != nil)
        #expect(core.borders.dormant[WindowID(4)] != nil)
        core.tiler.settings.borderStyle.enabled = false
        core.updateBorders()
        #expect(core.borders.dormant.isEmpty)
    }

    @Test("A finished bump keeps a dormant ring's corner radius")
    func bumpTeardownKeepsDormantRadius() {
        let border = BorderManager()
        border.movePanel = { _, _ in false }
        defer { border.clear() }
        border.sync([spec(1)])
        border.sync([])
        border.retireBumpTransient(WindowID(1))
        #expect(border.cornerRadii[WindowID(1)] != nil)
        border.sync([], alive: [], reassertOrder: true)
        border.cornerRadii[WindowID(1)] = 10
        border.retireBumpTransient(WindowID(1))
        #expect(border.cornerRadii[WindowID(1)] == nil)
    }
}
