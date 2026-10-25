import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// #2531: a ring that took its room while animating keeps it until
/// the late resync, so a focus jump between scroll steps resizes no
/// panel — a resize is an AppKit `setFrame` whose fenced commit
/// waited ~500 ms on a slow app. A ring that never animated takes
/// no room for it.
@Suite("Border rings hold their room until the resync")
@MainActor
struct BorderRoomHoldTests {
    private let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
    private let frame = CGRect(x: 0, y: 0, width: 400, height: 300)

    private func manager(_ backend: RoomBackend) -> BorderManager {
        let border = BorderManager()
        border.movePanel = { _, _ in false }
        border.backendFactory = { _ in backend }
        border.watch.override = { _ in true }
        border.roomScreenOverride = screen
        return border
    }

    private func spec(_ id: UInt32) -> BorderManager.Spec {
        BorderManager.Spec(
            window: WindowID(id),
            frame: frame,
            colorHex: "#FF0000",
            width: 4,
            cornerStyle: .rounded
        )
    }

    @Test("An animated ring keeps its room while the resync is owed")
    func animatedRingKeepsRoom() {
        let backend = RoomBackend()
        let border = manager(backend)
        defer { border.clear() }
        border.sync([spec(9)], alive: nil, reassertOrder: false)
        border.isAnimating = { _ in true }
        border.apply(WindowID(9), windowFrame: frame)
        let room = BorderManager.room(around: screen, scale: 2)
        #expect(backend.rooms.last == room)
        border.isAnimating = { _ in false }
        border.roomsHeld = true
        border.apply(WindowID(9), windowFrame: frame.offsetBy(dx: 40, dy: 0))
        #expect(backend.rooms.last == room)
        border.roomsHeld = false
        border.apply(WindowID(9), windowFrame: frame)
        #expect(backend.rooms.last == .some(nil))
    }

    @Test("A ring that never animated takes no held room")
    func stillRingTakesNoRoom() {
        let backend = RoomBackend()
        let border = manager(backend)
        defer { border.clear() }
        border.roomsHeld = true
        border.sync([spec(9)], alive: nil, reassertOrder: false)
        border.apply(WindowID(9), windowFrame: frame)
        #expect(backend.rooms.allSatisfy { $0 == nil })
    }

    @Test("Scheduling the resync holds rooms; running it lets them go")
    func resyncOwnsTheHold() {
        let core = makeTestCore()
        core.borders.heldRooms = [WindowID(9)]
        core.scheduleBorderResync()
        #expect(core.borders.roomsHeld)
        core.runBorderResync()
        #expect(!core.borders.roomsHeld)
        #expect(core.borders.heldRooms.isEmpty)
        core.deferred.cancel(.borderResync)
    }
}

private final class RoomBackend: BorderOverlayBackend {
    let orderMode: BorderGeometry.Order = .below
    private(set) var rooms: [CGRect?] = []
    func update(
        geometry: BorderGeometry,
        colorHex: String,
        screen: NSScreen?,
        room: CGRect?
    ) {
        rooms.append(room)
    }
    func order(relativeTo windowNumber: CGWindowID) {}
    func hide() {}
}
