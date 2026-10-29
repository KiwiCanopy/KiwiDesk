import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The pocket plate as a drop target (#2678): every window move shows
/// it, faded while empty; it lights under a window the pocket would
/// take, and the drop pockets that window; a window it would refuse
/// lights nothing and goes back. A resize shows nothing.
@Suite(
    "Pocket drop",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct PocketDropTests {
    private let one = WindowID(1)
    private let two = WindowID(2)
    private let start = CGRect(x: 100, y: 100, width: 600, height: 400)

    private func makeCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-drop-\(UUID().uuidString)")
        )
        for raw: UInt32 in [2, 1] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: 900_000 + pid_t(raw),
                        appName: "App\(raw)",
                        title: "Window \(raw)",
                        frame: start
                    )
                )
            )
        }
        let screen = try #require(NSScreen.main)
        let id = try #require(screen.kiwiDisplayID)
        let space = try #require(core.state.workspaces.activeSpace)
        core.state.workspaces.upsertDisplay(
            Display(id: id, name: "Main", frame: screen.frame)
        )
        core.state.workspaces.assign(space, to: id)
        // Pinned (tests.md, #531).
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 800)
        }
        return core
    }

    /// The pointer on the plate's centre, or well off it.
    private func point(_ core: KiwiCore, onPlate: Bool) {
        let frame = core.pocketPlate.specs.values.first?.frame ?? .zero
        let at =
            onPlate
            ? CGPoint(x: frame.midX, y: frame.midY)
            : CGPoint(x: frame.minX - 400, y: frame.minY + 400)
        core.drag.cursorLocation = { at }
    }

    private func move(_ core: KiwiCore, _ id: WindowID, resize: Bool = false) {
        var frame = start.offsetBy(dx: 30, dy: 30)
        if resize { frame.size.width += 50 }
        core.handleDragMove(id, start: start, frame: frame)
    }

    private func end(_ core: KiwiCore, _ id: WindowID) {
        core.handleDragEnd(
            id,
            start: start,
            frame: start.offsetBy(dx: 30, dy: 30)
        )
    }

    @Test("a window move shows the empty plate, faded and uncounted")
    func moveShowsThePlate() throws {
        let core = try makeCore()
        point(core, onPlate: false)
        move(core, one)
        let shown = try #require(core.pocketPlate.specs.values.first)
        #expect(shown.faded)
        #expect(shown.count == "")
        #expect(!shown.dropHovered)
        end(core, one)
        #expect(core.pocketPlate.specs.values.first == nil)
    }

    @Test("a resize shows no plate")
    func resizeShowsNothing() throws {
        let core = try makeCore()
        point(core, onPlate: false)
        move(core, one, resize: true)
        #expect(core.pocketPlate.specs.values.first == nil)
    }

    @Test("a drop on the plate pockets the window, lit while over it")
    func dropPockets() throws {
        let core = try makeCore()
        point(core, onPlate: false)
        move(core, one)
        point(core, onPlate: true)
        move(core, one)
        #expect(core.pocketPlate.specs.values.first?.dropHovered == true)
        end(core, one)
        #expect(core.state.pocketPhase(of: one) == .pocketed)
        #expect(core.pocketPlate.dragging == nil)
    }

    @Test("a drop off the plate pockets nothing")
    func dropOffPlate() throws {
        let core = try makeCore()
        point(core, onPlate: false)
        move(core, one)
        end(core, one)
        #expect(core.state.pocket.isEmpty)
    }

    @Test("under One window, taken, the plate lights not and refuses")
    func takenRefuses() throws {
        let core = try makeCore()
        core.execute("pocket", args: [.number(Double(one.raw))])
        point(core, onPlate: false)
        move(core, two)
        point(core, onPlate: true)
        move(core, two)
        #expect(core.pocketPlate.specs.values.first?.dropHovered == false)
        end(core, two)
        #expect(core.state.pocketPhase(of: two) == nil)
        #expect(core.state.pocketedWindows == [one])
        // Refused, the ordinary drop took it: the plate is done.
        #expect(core.pocketPlate.dragging == nil)
    }

    @Test("a resize latches off the plate it began as a move")
    func resizeLatches() throws {
        let core = try makeCore()
        point(core, onPlate: true)
        move(core, one)
        #expect(core.pocketPlate.specs.values.first != nil)
        move(core, one, resize: true)
        #expect(core.pocketPlate.specs.values.first == nil)
        move(core, one)
        #expect(core.pocketPlate.specs.values.first == nil)
        end(core, one)
        #expect(core.state.pocket.isEmpty)
        #expect(core.pocketPlate.resizing == nil)
    }

    @Test("an out window dropped in files its pre-drag frame")
    func outWindowKeepsItsFrame() throws {
        let core = try makeCore()
        core.handle(.windowFocused(one))
        core.execute("toggle_pocket_window")
        let before = try #require(core.state.windows[one]?.frame)
        point(core, onPlate: false)
        core.handleDragMove(
            one,
            start: before,
            frame: before.offsetBy(dx: 30, dy: 30)
        )
        point(core, onPlate: true)
        core.handleDragMove(
            one,
            start: before,
            frame: before.offsetBy(dx: 300, dy: 300)
        )
        // The echoes fold the dragged frame in, as on the device.
        core.state.apply(.windowMoved(one, before.offsetBy(dx: 300, dy: 300)))
        core.handleDragEnd(
            one,
            start: before,
            frame: before.offsetBy(dx: 300, dy: 300)
        )
        #expect(core.state.pocketPhase(of: one) == .pocketed)
        let filed = core.state.pocketSlot(of: one)?.frames.values
        #expect(filed.map { Array($0) } == [before])
    }

    @Test("a first frame with no delta, or a shrink, shows no plate")
    func undecidedOrShrinkShowsNothing() throws {
        let core = try makeCore()
        point(core, onPlate: false)
        core.handleDragMove(one, start: start, frame: start)
        #expect(core.pocketPlate.specs.values.first == nil)
        var shrunk = start.offsetBy(dx: 30, dy: 30)
        shrunk.size.width -= 50
        core.handleDragMove(one, start: start, frame: shrunk)
        #expect(core.pocketPlate.specs.values.first == nil)
        #expect(core.pocketPlate.resizing == one)
    }

    @Test("an unlit plate takes no drop, even with the pointer on it")
    func unlitTakesNothing() throws {
        let core = try makeCore()
        point(core, onPlate: false)
        move(core, one)
        // On the plate at the release, but lit by no move.
        point(core, onPlate: true)
        end(core, one)
        #expect(core.state.pocket.isEmpty)
    }

    @Test("a drop clears the light")
    func dropClearsDragState() throws {
        let core = try makeCore()
        point(core, onPlate: false)
        move(core, one)
        point(core, onPlate: true)
        move(core, one)
        end(core, one)
        #expect(!core.pocketPlate.dropHovered)
    }

    @Test("with one window inside the drag's plate is not faded")
    func oneInsideIsNotFaded() throws {
        let core = try makeCore()
        core.execute("pocket", args: [.number(Double(one.raw))])
        point(core, onPlate: false)
        move(core, two)
        #expect(core.pocketPlate.specs.values.first?.faded == false)
    }

    @Test("a cancelled drag hides the plate it showed")
    func cancelHides() throws {
        let core = try makeCore()
        point(core, onPlate: false)
        move(core, one)
        #expect(core.pocketPlate.specs.values.first != nil)
        core.cancelDrag(one)
        #expect(core.pocketPlate.dragging == nil)
        #expect(core.pocketPlate.specs.values.first == nil)
    }
}
