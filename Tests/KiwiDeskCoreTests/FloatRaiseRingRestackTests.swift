import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// #2284: a quiet raise cannot beat the frontmost app's key window,
/// so the float-tier raise lands a float directly under the focused
/// window — between that window and its ring, which was ordered
/// against it before the raise. The float's reorder event re-stacks
/// only the float's ring, so the raise's landing re-stacks the
/// anchor's overlays through the watch's one fan-out. The drain
/// that calls the landing is not reachable here;
/// `FloatRaiseLandingWiringTests` pins that call.
@Suite("Float raise re-stacks the anchor's ring (#2284)", .serialized)
@MainActor
struct FloatRaiseRingRestackTests {
    private final class Orders {
        var counts: [CGWindowID: Int] = [:]
    }

    private func makeCore(_ orders: Orders) -> KiwiCore {
        let directory =
            testTemporaryDirectory
            .appendingPathComponent("kiwidesk-tests-\(UUID().uuidString)")
        let core = makeTestCore(configDirectory: directory)
        core.borders.movePanel = { _, _ in false }
        core.borders.watch.override = { _ in true }
        core.borders.backendFactory = { _ in
            CountingBackend { orders.counts[$0, default: 0] += 1 }
        }
        return core
    }

    private func spec(_ id: UInt32) -> BorderManager.Spec {
        BorderManager.Spec(
            window: WindowID(id),
            frame: CGRect(x: 0, y: 0, width: 400, height: 300),
            colorHex: "#FF0000",
            width: 4,
            cornerStyle: .rounded
        )
    }

    /// Space "1" holds windows 1 and 2, 1 focused, each ringed.
    private func seed(_ core: KiwiCore) {
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        for id: UInt32 in 1...2 {
            core.state.windows.upsert(
                ManagedWindow(
                    id: WindowID(id),
                    pid: 100,
                    appName: "App",
                    title: "Title",
                    frame: CGRect(x: 0, y: 0, width: 400, height: 300)
                )
            )
            core.state.workspaces.add(WindowID(id), to: "1")
        }
        core.state.workspaces.focus(WindowID(1), in: "1")
        core.borders.sync(
            [spec(1), spec(2)],
            alive: nil,
            reassertOrder: false
        )
    }

    @Test("The landing re-stacks the anchor's ring and no other")
    func landingRestacksTheAnchor() {
        let orders = Orders()
        let core = makeCore(orders)
        defer { core.borders.clear() }
        seed(core)
        #expect(orders.counts == [1: 1, 2: 1])
        let generation = core.zOrderRaiseGeneration.bump()
        core.landFloatRaise(thenFocus: WindowID(1), generation: generation)
        #expect(orders.counts == [1: 2, 2: 1])
    }

    @Test("A stale sequence's landing re-stacks nothing")
    func staleLandingStandsDown() {
        let orders = Orders()
        let core = makeCore(orders)
        defer { core.borders.clear() }
        seed(core)
        let stale = core.zOrderRaiseGeneration.bump()
        _ = core.zOrderRaiseGeneration.bump()
        core.landFloatRaise(thenFocus: WindowID(1), generation: stale)
        #expect(orders.counts == [1: 1, 2: 1])
    }

    @Test("A landing for a focus that moved on re-stacks nothing")
    func movedFocusStandsDown() {
        let orders = Orders()
        let core = makeCore(orders)
        defer { core.borders.clear() }
        seed(core)
        let generation = core.zOrderRaiseGeneration.bump()
        core.landFloatRaise(thenFocus: WindowID(2), generation: generation)
        #expect(orders.counts == [1: 1, 2: 1])
    }
}

@MainActor
private final class CountingBackend: BorderOverlayBackend {
    let orderMode: BorderGeometry.Order = .below
    private let onOrder: (CGWindowID) -> Void
    init(onOrder: @escaping (CGWindowID) -> Void) {
        self.onOrder = onOrder
    }
    func update(
        geometry: BorderGeometry,
        colorHex: String,
        screen: NSScreen?,
        room: CGRect?
    ) {}
    func order(relativeTo windowNumber: CGWindowID) {
        onOrder(windowNumber)
    }
    func hide() {}
}
