import AppKit
import Testing

@testable import KiwiDeskCore

/// The facade owns the ring's order mode and rebuilds geometry for
/// it on every render (#357). An `above` geometry (visible hairline
/// lap) differs from a `below` one (masked overlap), so the mode
/// must drive the geometry, not a value precomputed upstream.
@Suite("Border order mode")
@MainActor
struct BorderOrderModeTests {
    private let frame = CGRect(x: 10, y: 20, width: 300, height: 200)

    @Test("An above backend receives above-order geometry")
    func aboveBackendGetsAboveGeometry() {
        let backend = GeometryCapturingBackend(orderMode: .above)
        let overlay = BorderOverlay(window: 7, backend: backend)
        overlay.update(
            frame: frame,
            width: 6,
            cornerStyle: .rounded,
            cornerRadius: 16,
            colorHex: "#0A84FF",
            screen: nil,
            room: nil
        )
        let expected = BorderGeometry.compute(
            windowFrame: frame,
            width: 6,
            cornerStyle: .rounded,
            order: .above
        )
        #expect(backend.lastGeometry == expected)
        // The on-window capped lap (1), not the hidden 5.
        #expect(backend.lastGeometry?.lineWidth == 7.0)
    }

    @Test("The injected corner radius drives the arc")
    func injectedRadiusDrivesGeometry() {
        let backend = GeometryCapturingBackend(orderMode: .above)
        let overlay = BorderOverlay(window: 7, backend: backend)
        // A non-default radius (10, not the 16 fallback) must flow
        // through to the stroke's corner radius — the radius path is
        // injectable rather than queried inside the facade (#357).
        overlay.update(
            frame: frame,
            width: 6,
            cornerStyle: .rounded,
            cornerRadius: 10,
            colorHex: "#0A84FF",
            screen: nil,
            room: nil
        )
        let atTen = BorderGeometry.compute(
            windowFrame: frame,
            width: 6,
            cornerStyle: .rounded,
            order: .above,
            systemRadius: 10
        )
        let atDefault = BorderGeometry.compute(
            windowFrame: frame,
            width: 6,
            cornerStyle: .rounded,
            order: .above,
            systemRadius: 16
        )
        #expect(backend.lastGeometry?.cornerRadius == atTen.cornerRadius)
        #expect(atTen.cornerRadius != atDefault.cornerRadius)
    }

    @Test("A below backend receives below-order geometry")
    func belowBackendGetsBelowGeometry() {
        let backend = GeometryCapturingBackend(orderMode: .below)
        let overlay = BorderOverlay(window: 7, backend: backend)
        overlay.update(
            frame: frame,
            width: 6,
            cornerStyle: .rounded,
            cornerRadius: 16,
            colorHex: "#0A84FF",
            screen: nil,
            room: nil
        )
        #expect(
            backend.lastGeometry?.lineWidth
                == 6 + BorderGeometry.hiddenOverlapCushion
        )
    }
}

@MainActor
private final class GeometryCapturingBackend: BorderOverlayBackend {
    let orderMode: BorderGeometry.Order
    var lastGeometry: BorderGeometry?

    init(orderMode: BorderGeometry.Order) {
        self.orderMode = orderMode
    }

    func update(
        geometry: BorderGeometry,
        colorHex: String,
        screen: NSScreen?,
        room: CGRect?
    ) {
        lastGeometry = geometry
    }

    func order(relativeTo windowNumber: CGWindowID) {}
    func hide() {}
}
