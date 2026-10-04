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
        let frame = CGRect(x: 10, y: 20, width: 300, height: 200)

        overlay.update(
            frame: frame,
            width: 4,
            cornerStyle: .rounded,
            cornerRadius: 16,
            colorHex: "#FF0000",
            screen: nil,
            room: nil
        )
        overlay.order(relativeTo: 7)
        backend.calls = []

        overlay.hide()
        overlay.update(
            frame: frame,
            width: 4,
            cornerStyle: .rounded,
            cornerRadius: 16,
            colorHex: "#FF0000",
            screen: nil,
            restoreVisibility: true,
            room: nil
        )
        overlay.update(
            frame: frame,
            width: 4,
            cornerStyle: .rounded,
            cornerRadius: 16,
            colorHex: "#FF0000",
            screen: nil,
            restoreVisibility: true,
            room: nil
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
}

@MainActor
private final class RecordingBorderBackend: BorderOverlayBackend {
    enum Call: Equatable {
        case update
        case order(CGWindowID)
        case hide
    }

    var calls: [Call] = []
    let orderMode: BorderGeometry.Order = .below

    func update(
        geometry: BorderGeometry,
        colorHex: String,
        screen: NSScreen?,
        room: CGRect?
    ) {
        calls.append(.update)
    }

    func order(relativeTo windowNumber: CGWindowID) {
        calls.append(.order(windowNumber))
    }

    func hide() {
        calls.append(.hide)
    }
}
