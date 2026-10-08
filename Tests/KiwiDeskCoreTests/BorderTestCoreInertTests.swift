import AppKit
import Testing

@testable import KiwiDeskCore

/// A test core's rings own no window and read no corner radius from
/// WindowServer (#1894). The twins' pins are held by spelling in
/// `BorderPanelSeamTests`; this holds that the backend pin reaches
/// the ring a sync actually builds.
@Suite("Test core rings are inert")
@MainActor
struct BorderTestCoreInertTests {
    private func spec(_ id: UInt32) -> BorderManager.Spec {
        BorderManager.Spec(
            window: WindowID(id),
            frame: CGRect(x: 0, y: 0, width: 400, height: 300),
            colorHex: "#FF0000",
            width: 4,
            cornerStyle: .rounded
        )
    }

    @Test("a synced ring takes the inert backend in the manager's order")
    func syncedRingIsInert() throws {
        let core = makeTestCore()
        defer { core.borders.clear() }
        core.borders.sync([spec(7)])
        let ring = try #require(core.borders.overlays[WindowID(7)])
        let backend = try #require(ring.backend as? InertBorderBackend)
        #expect(backend.orderMode == .below)
    }
}
