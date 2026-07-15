import AppKit
import Testing

@testable import KiwiDeskCore

@Suite("Border overlay visibility")
@MainActor
struct BorderOverlayVisibilityTests {
    @Test("First reconcile after hide restores raw overlay order")
    func reconcileRestoresHiddenOverlayOnce() {
        let backend = RecordingBorderBackend()
        let overlay = BorderOverlay(window: 7, backend: backend)
        let geometry = BorderGeometry.compute(
            windowFrame: CGRect(x: 10, y: 20, width: 300, height: 200),
            width: 4,
            cornerStyle: .rounded
        )

        overlay.update(
            geometry: geometry,
            colorHex: "#FF0000",
            screen: nil
        )
        overlay.order(above: 7)
        backend.calls = []

        overlay.hide()
        overlay.update(
            geometry: geometry,
            colorHex: "#FF0000",
            screen: nil,
            restoreVisibility: true
        )
        overlay.update(
            geometry: geometry,
            colorHex: "#FF0000",
            screen: nil,
            restoreVisibility: true
        )

        #expect(
            backend.calls == [
                .hide,
                .update,
                .order(7),
                .update,
            ]
        )
    }

    @Test("Failed private hide falls back and stays hidden")
    func hideFailurePreservesIntent() {
        let primary = RecordingBorderBackend()
        primary.hideSucceeds = false
        let fallback = RecordingBorderBackend()
        let overlay = BorderOverlay(
            window: 7,
            backend: primary,
            fallback: fallback
        )
        let geometry = BorderGeometry.compute(
            windowFrame: CGRect(x: 10, y: 20, width: 300, height: 200),
            width: 4,
            cornerStyle: .rounded
        )
        overlay.update(
            geometry: geometry,
            colorHex: "#FF0000",
            screen: nil
        )
        overlay.order(above: 7)
        primary.calls = []

        overlay.hide()
        #expect(primary.calls == [.hide])
        #expect(fallback.calls == [.update, .hide])

        overlay.order(above: 7)
        #expect(fallback.calls == [.update, .hide, .order(7)])
    }
}

@MainActor
private final class RecordingBorderBackend: BorderOverlayBackend {
    enum Call: Equatable {
        case update
        case order(CGWindowID)
        case hide
    }

    var calls: [Call] = []
    var hideSucceeds = true

    func update(
        geometry: BorderGeometry,
        colorHex: String,
        screen: NSScreen?
    ) -> Bool {
        calls.append(.update)
        return true
    }

    func order(above windowNumber: CGWindowID) -> Bool {
        calls.append(.order(windowNumber))
        return true
    }

    func hide() -> Bool {
        calls.append(.hide)
        return hideSucceeds
    }
}
