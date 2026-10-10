import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A ring belongs to its window's Desktop (#2149): it spans every
/// Desktop only while its window is carried (#1145), and it is
/// ordered out before an order only where it must move Desktops —
/// it stopped spanning, or `sync` orders it on a screen now showing
/// another Desktop. Every other order costs no extra round trip.
@Suite("A ring spans Desktops only while carried", .serialized)
@MainActor
struct BorderDesktopSpanTests {
    @MainActor
    private final class Recorder: BorderOverlayBackend {
        let orderMode: BorderGeometry.Order = .below
        var calls: [String] = []
        var spans = false
        func update(
            geometry: BorderGeometry,
            colorHex: String,
            screen: NSScreen?,
            room: CGRect?
        ) {}
        func order(relativeTo windowNumber: CGWindowID) {
            calls.append("order")
        }
        func hide() { calls.append("hide") }
        func setSpansDesktops(_ on: Bool) { spans = on }
    }

    private func ring() -> (BorderOverlay, Recorder) {
        let backend = Recorder()
        return (BorderOverlay(window: 7, backend: backend), backend)
    }

    /// One `sync` order: the placement facts, then the order.
    private func syncOrder(
        _ overlay: BorderOverlay,
        on desktop: UInt64?,
        spans: Bool = false
    ) {
        overlay.place(spansDesktops: spans, desktop: desktop)
        overlay.order(relativeTo: 7)
    }

    @Test("A real ring panel is built on one Desktop")
    func newPanelIsSingleDesktop() throws {
        let overlay = BorderOverlay(
            window: 7,
            order: .below,
            movePanel: { _, _ in false }
        )
        let backend = try #require(overlay.backend as? AppKitBorderOverlay)
        overlay.update(
            frame: CGRect(x: -9_000, y: -9_000, width: 40, height: 30),
            width: 4,
            cornerStyle: .rounded,
            cornerRadius: 16,
            colorHex: "#FF0000",
            screen: nil,
            room: nil
        )
        defer { overlay.hide() }
        let behavior = try #require(backend.panelBehavior)
        #expect(!behavior.contains(.canJoinAllSpaces))
        backend.setSpansDesktops(true)
        #expect(backend.panelBehavior?.contains(.canJoinAllSpaces) == true)
    }

    @Test("An order on the same Desktop costs no re-home")
    func sameDesktopOrdersOnce() {
        let (overlay, backend) = ring()
        syncOrder(overlay, on: 1)
        syncOrder(overlay, on: 1)
        // A reorder event orders with the facts `sync` left.
        overlay.order(relativeTo: 7)
        #expect(backend.calls == ["order", "order", "order"])
    }

    @Test("An order on another Desktop re-homes first")
    func movedWindowRehomes() {
        let (overlay, backend) = ring()
        syncOrder(overlay, on: 1)
        overlay.retire()
        syncOrder(overlay, on: 2)
        syncOrder(overlay, on: 2)
        #expect(backend.calls == ["order", "hide", "order", "order"])
    }

    /// A ring that stays wanted across a Desktop change — its
    /// window still focused in a Space both Desktops show — is
    /// never retired, so the change alone must owe the order.
    @Test("A live ring placed on another Desktop owes a re-home")
    func liveRingOwesTheRehome() {
        let (overlay, backend) = ring()
        syncOrder(overlay, on: 1)
        #expect(!overlay.needsOrder)
        overlay.place(spansDesktops: false, desktop: 2)
        #expect(overlay.needsOrder)
        overlay.order(relativeTo: 7)
        #expect(!overlay.needsOrder)
        #expect(backend.calls == ["order", "hide", "order"])
    }

    @Test("An unknown Desktop never re-homes")
    func unknownDesktopStays() {
        let (overlay, backend) = ring()
        syncOrder(overlay, on: 1)
        syncOrder(overlay, on: nil)
        #expect(backend.calls == ["order", "order"])
    }

    @Test("A spanning ring is never re-homed by Desktop")
    func spanningRingStays() {
        let (overlay, backend) = ring()
        syncOrder(overlay, on: 1, spans: true)
        #expect(backend.spans)
        syncOrder(overlay, on: 2, spans: true)
        #expect(backend.calls == ["order", "order"])
    }

    @Test("A ring that stops spanning owes one re-home")
    func unspanRehomesOnce() {
        let (overlay, backend) = ring()
        syncOrder(overlay, on: 1, spans: true)
        overlay.place(spansDesktops: false, desktop: 2)
        #expect(!backend.spans)
        #expect(overlay.needsOrder)
        overlay.order(relativeTo: 7)
        syncOrder(overlay, on: 2)
        #expect(backend.calls == ["order", "hide", "order", "order"])
    }

    @Test("A never-ordered ring is not ordered out")
    func freshRingSkipsTheRehome() {
        let (overlay, backend) = ring()
        overlay.place(spansDesktops: true, desktop: nil)
        overlay.place(spansDesktops: false, desktop: nil)
        syncOrder(overlay, on: 1)
        #expect(backend.calls == ["order"])
    }
}
