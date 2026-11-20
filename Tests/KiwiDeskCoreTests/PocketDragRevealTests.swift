import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `kiwishelf.pocket_drag_reveal` off (#3522): a window drag brings
/// no pocket out and raises no handle, while a pocket already shown
/// still takes a drop, an Auto handle's tab takes none, and the drag
/// still counts as a window moving for the bars' reveal (#2795).
/// Each case runs its control first.
@Suite(
    "Pocket drag reveal (#3522)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct PocketDragRevealTests {
    private let one = WindowID(1)
    private let start = CGRect(x: 100, y: 100, width: 600, height: 400)

    private func makeCore(_ show: String) throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-dragrev-\(UUID().uuidString)")
        )
        // Hidden bars leave the pocket its handle on any edge (#2784).
        core.tiler.settings.spaceBarStyle.visibility = .hidden
        core.execute(
            "kiwishelf.set_pocket_visibility",
            args: [.string(show)]
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
        core.updateBars()
        return core
    }

    private func reveal(_ core: KiwiCore, _ on: Bool) {
        let response = core.execute(
            "kiwishelf.set_pocket_drag_reveal",
            args: [.bool(on)]
        )
        #expect(response.isSuccess)
    }

    /// The pointer on the drawn pocket's centre, or well off it.
    private func point(_ core: KiwiCore, onPocket: Bool) {
        let frame = core.pocketPlate.specs.values.first?.frame ?? .zero
        let at =
            onPocket
            ? CGPoint(x: frame.midX, y: frame.midY)
            : CGPoint(x: frame.minX - 400, y: frame.minY + 400)
        core.drag.cursorLocation = { at }
    }

    private func move(_ core: KiwiCore) {
        core.handleDragMove(
            one,
            start: start,
            frame: start.offsetBy(dx: 30, dy: 30)
        )
    }

    private func end(_ core: KiwiCore) {
        core.handleDragEnd(
            one,
            start: start,
            frame: start.offsetBy(dx: 30, dy: 30)
        )
    }

    @Test("the setting defaults on and round-trips through its verb")
    func verbWrites() throws {
        #expect(KiwiShelf().pocketDragReveal)
        let core = try makeCore("hidden")
        reveal(core, false)
        #expect(!core.tiler.settings.kiwishelf.pocketDragReveal)
        let refused = core.execute(
            "kiwishelf.set_pocket_drag_reveal",
            args: [.string("no")]
        )
        #expect(!refused.isSuccess)
    }

    @Test("off, a Hidden pocket stands for no drag")
    func hiddenStaysAway() throws {
        // Control: on, the drag shows it.
        let on = try makeCore("hidden")
        point(on, onPocket: false)
        move(on)
        #expect(!on.pocketPlate.specs.isEmpty)
        end(on)
        let core = try makeCore("hidden")
        reveal(core, false)
        point(core, onPocket: false)
        move(core)
        #expect(core.pocketPlate.dragging == one)
        #expect(!core.pocketStands)
        #expect(core.pocketPlate.specs.isEmpty)
        let display = try #require(core.state.workspaces.allDisplays.first)
        #expect(!core.pocketStands(on: display.id))
        end(core)
    }

    @Test("off, an Auto handle neither rises nor takes a drop")
    func tabTakesNoDrop() throws {
        // Control: on, the drag raises the handle.
        let on = try makeCore("auto")
        point(on, onPocket: false)
        move(on)
        #expect(on.pocketPlate.specs.values.first?.risen == true)
        end(on)
        let core = try makeCore("auto")
        reveal(core, false)
        point(core, onPocket: false)
        move(core)
        let tab = try #require(core.pocketPlate.specs.values.first)
        #expect(!tab.risen)
        #expect(tab.isTab)
        point(core, onPocket: true)
        move(core)
        #expect(core.pocketPlate.specs.values.first?.dropHovered == false)
        end(core)
        #expect(core.state.pocketPhase(of: one) == nil)
    }

    @Test("off, an Always pocket still takes a drop")
    func shownPocketTakesTheDrop() throws {
        // Control: off, a drag off the pocket pockets nothing.
        let off = try makeCore("always")
        reveal(off, false)
        point(off, onPocket: false)
        move(off)
        end(off)
        #expect(off.state.pocketPhase(of: one) == nil)
        let core = try makeCore("always")
        reveal(core, false)
        point(core, onPocket: false)
        move(core)
        point(core, onPocket: true)
        move(core)
        #expect(core.pocketPlate.specs.values.first?.dropHovered == true)
        end(core)
        #expect(core.state.pocketPhase(of: one) == .pocketed)
    }

    /// A handle its list holds risen is shown, so it takes the drop.
    @Test("off, a handle its list holds up still takes a drop")
    func listedHandleTakesTheDrop() throws {
        let core = try makeCore("auto")
        reveal(core, false)
        let display = try #require(core.state.workspaces.allDisplays.first)
        // Control: the resting tab takes none (tabTakesNoDrop).
        core.pocketPlate.openingList = display.id
        point(core, onPocket: false)
        move(core)
        let risen = try #require(core.pocketPlate.specs.values.first)
        #expect(risen.risen)
        #expect(!risen.isTab)
        point(core, onPocket: true)
        move(core)
        #expect(core.pocketPlate.specs.values.first?.dropHovered == true)
        end(core)
        #expect(core.state.pocketPhase(of: one) == .pocketed)
    }

    /// The drag stays recorded, so the bars' reveal still reads a
    /// window moving (#2795) — the seam the gate must not sit at.
    @Test("off, a drag still counts as a window moving")
    func dragStillMoves() throws {
        let core = try makeCore("hidden")
        reveal(core, false)
        core.drag.isAnimating = { _ in false }
        core.drag.isMousePressed = { false }
        // Control: no drag, no window moving.
        #expect(!core.windowMoveInFlight)
        point(core, onPocket: false)
        move(core)
        core.drag.windowMoved(
            one,
            frame: start.offsetBy(dx: 30, dy: 30),
            validated: true
        )
        #expect(core.windowMoveInFlight)
    }
}
