import AppKit
import Testing

@testable import KiwiDeskCore

/// The glow-driven backend swap (#533): a glow ring must render
/// on a backend whose `rendersGlow` is true, swapping two-way on
/// the toggle through the facade's injection seam. Pins the
/// swapped/hidden/restore interplay that ships no other way —
/// the production factories build real windows.
@Suite("Border glow backend swap")
@MainActor
struct BorderSwapTests {
    private let frame = CGRect(x: 10, y: 20, width: 300, height: 200)

    private func render(
        _ overlay: BorderOverlay,
        glow: Bool,
        restore: Bool = false
    ) {
        overlay.update(
            frame: frame,
            width: 4,
            cornerStyle: .rounded,
            cornerRadius: 16,
            colorHex: "#FF0000",
            screen: nil,
            glow: glow,
            restoreVisibility: restore
        )
    }

    @Test("Glow on a non-glow backend swaps and re-orders")
    func glowSwapsToFallback() {
        let primary = SwapSpyBackend(rendersGlow: false)
        let fallback = SwapSpyBackend(rendersGlow: true)
        let overlay = BorderOverlay(
            window: 7,
            backend: primary,
            fallback: fallback
        )
        render(overlay, glow: false)
        overlay.order(relativeTo: 7)
        primary.calls = []

        render(overlay, glow: true)
        // Old backend hidden; fresh one rendered AND re-ordered
        // — a swapped ring must not stay drawn-but-unstacked.
        #expect(primary.calls == [.hide])
        #expect(fallback.calls == [.update, .order(7)])
    }

    @Test("Swap while hidden re-hides the fresh backend")
    func swapWhileHiddenStaysHidden() {
        let primary = SwapSpyBackend(rendersGlow: false)
        let fallback = SwapSpyBackend(rendersGlow: true)
        let overlay = BorderOverlay(
            window: 7,
            backend: primary,
            fallback: fallback
        )
        render(overlay, glow: false)
        overlay.hide()
        primary.calls = []

        render(overlay, glow: true)
        #expect(fallback.calls == [.update, .hide])
    }

    @Test("restoreVisibility across a swap restores exactly once")
    func swapWithRestore() {
        let primary = SwapSpyBackend(rendersGlow: false)
        let fallback = SwapSpyBackend(rendersGlow: true)
        let overlay = BorderOverlay(
            window: 7,
            backend: primary,
            fallback: fallback
        )
        render(overlay, glow: false)
        overlay.hide()
        primary.calls = []

        render(overlay, glow: true, restore: true)
        #expect(fallback.calls == [.update, .order(7)])
    }

    @Test("Glow off swaps back to the injected preferred backend")
    func glowOffSwapsBack() {
        let primary = SwapSpyBackend(rendersGlow: false)
        let fallback = SwapSpyBackend(rendersGlow: true)
        let preferred = SwapSpyBackend(rendersGlow: false)
        let overlay = BorderOverlay(
            window: 7,
            backend: primary,
            fallback: fallback,
            preferred: { _ in preferred }
        )
        render(overlay, glow: true)
        fallback.calls = []

        render(overlay, glow: false)
        #expect(fallback.calls.first == .hide)
        #expect(preferred.calls == [.update, .order(7)])
    }

    @Test("A nil preferred factory retires the swap-back for good")
    func nilPreferredRetires() {
        let primary = SwapSpyBackend(rendersGlow: false)
        let fallback = SwapSpyBackend(rendersGlow: true)
        let overlay = BorderOverlay(
            window: 7,
            backend: primary,
            fallback: fallback
        )
        render(overlay, glow: true)
        fallback.calls = []

        // Default seam preferred factory returns nil — the ring
        // stays on the glow-capable backend, and stops asking.
        render(overlay, glow: false)
        render(overlay, glow: false)
        #expect(fallback.calls == [.update, .update])
    }
}

private final class SwapSpyBackend: BorderOverlayBackend {
    enum Call: Equatable {
        case update
        case order(CGWindowID)
        case hide
    }

    var calls: [Call] = []
    let rendersGlow: Bool
    let orderMode: BorderGeometry.Order = .below

    init(rendersGlow: Bool) {
        self.rendersGlow = rendersGlow
    }

    func update(
        geometry: BorderGeometry,
        colorHex: String,
        screen: NSScreen?
    ) -> Bool {
        calls.append(.update)
        return true
    }

    func order(relativeTo windowNumber: CGWindowID) -> Bool {
        calls.append(.order(windowNumber))
        return true
    }

    func hide() -> Bool {
        calls.append(.hide)
        return true
    }
}
