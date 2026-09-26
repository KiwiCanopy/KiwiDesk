import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A flag float dropped by hand on another display joins that
/// display's active Space at the drop (#1686), through the real
/// `handleDragEnd`. Displays are faked through `displayAt`, the
/// `DragCrossingTests` fixture shape. Both fake displays fall back
/// to the one host screen, so a re-anchor stands down on
/// `source == dest` and this suite cannot see one —
/// `PendingSpaceSeamTests` ▸ `dropCommitNeverReanchors` and
/// `dropRefileTakesTheDropCommit` are that net. Nor can it see the
/// ORDER of fold, re-file and clamp in `handleDragEnd`, which no
/// fake display paints a strip for — `FloatDropOrderSeamTests`
/// pins it.
@Suite("A float dropped on another display (#1686)", .serialized)
@MainActor
struct FloatDropRefileTests {
    private let float = WindowID(1)
    private let drop = CGRect(x: 1400, y: 50, width: 400, height: 400)

    /// Space "1" (windows 1, 2) on display 1, an empty space "2"
    /// on display 2; left half display 1, right half display 2.
    private func makeCore(
        cursorX: CGFloat = 1500,
        sticky: StickyScope = .none
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-float-drop-\(UUID().uuidString)"
                )
        )
        for raw in [UInt32(1), 2] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: 1,
                        appName: "App\(raw)",
                        stickyScope: raw == 1 ? sticky : .none
                    )
                )
            )
        }
        core.state.workspaces.assign(SpaceID(1), to: DisplayID(1))
        core.state.workspaces.assign("2", to: DisplayID(2))
        core.drag.isMousePressed = { false }
        core.drag.cursorLocation = { CGPoint(x: cursorX, y: 100) }
        core.dragCrossing.displayAt = { point in
            point.x < 1000 ? DisplayID(1) : DisplayID(2)
        }
        return core
    }

    private func dropFloat(_ core: KiwiCore) {
        core.handleDragEnd(
            float,
            start: CGRect(x: 100, y: 50, width: 400, height: 400),
            frame: drop
        )
    }

    @Test("a flag float joins the display it was dropped on")
    func flagFloatJoinsTheDisplay() {
        let core = makeCore()
        core.state.setFloating(float, true)
        dropFloat(core)
        #expect(core.state.workspaces.space(of: float) == SpaceID("2"))
        #expect(
            core.state.workspaces[SpaceID(1)]?.windows == [WindowID(2)]
        )
        // The display follows the drop, as a tiled one's does.
        #expect(core.activeSpace?.id == SpaceID("2"))
        #expect(core.state.windows[float]?.isFloating == true)
    }

    /// The retile the re-file runs judges the state frame, so the
    /// drop's real frame is folded first — never a lagging echo.
    @Test("the drop's own frame is what state holds")
    func dropFrameIsFolded() {
        let core = makeCore()
        core.state.setFloating(float, true)
        let stale = CGRect(x: 100, y: 50, width: 400, height: 400)
        core.state.apply(.windowMoved(float, stale))
        dropFloat(core)
        #expect(core.state.windows[float]?.frame == drop)
    }

    @Test("a drop on the same display keeps its Space")
    func sameDisplayStays() {
        let core = makeCore(cursorX: 500)
        core.state.setFloating(float, true)
        dropFloat(core)
        #expect(core.state.workspaces.space(of: float) == SpaceID(1))
    }

    @Test("a sticky float is not re-filed, either scope")
    func stickyStays() {
        for scope in [StickyScope.display, .global] {
            let core = makeCore(sticky: scope)
            core.state.setFloating(float, true)
            dropFloat(core)
            #expect(
                core.state.workspaces.space(of: float) == SpaceID(1)
            )
        }
    }

    /// Floating only because of its Space, onto a tiled Space: it
    /// joins and takes the flag, so the layout does not tile it
    /// (owner ruling 2026-09-26).
    @Test("a floating-mode member joins a tiled Space as a float")
    func floatingModeMemberJoinsTiled() {
        let core = makeCore()
        core.state.workspaces.setMode(SpaceID(1), .floating)
        #expect(core.state.windows[float]?.isFloating == false)
        dropFloat(core)
        #expect(core.state.workspaces.space(of: float) == SpaceID("2"))
        #expect(core.state.windows[float]?.isFloating == true)
        // A MANUAL override, as the float verb writes: detection
        // cannot re-tile it, and it reopens floating (owner
        // ruling 2026-09-26).
        #expect(core.state.manualFloatOverrides[float] == true)
    }

    @Test("a floating-mode member joins a floating Space unflagged")
    func floatingModeMemberJoinsFloating() {
        let core = makeCore()
        core.state.workspaces.setMode(SpaceID(1), .floating)
        core.state.workspaces.setMode("2", .floating)
        dropFloat(core)
        #expect(core.state.workspaces.space(of: float) == SpaceID("2"))
        #expect(core.state.windows[float]?.isFloating == false)
        #expect(core.state.manualFloatOverrides[float] == nil)
    }

    /// A flag float counts as landing unmanaged in any Space, so
    /// the origin is the window's own Space, never the active one.
    @Test("a float from a Space that is not active still joins")
    func inactiveHomeJoins() {
        let core = makeCore()
        core.state.setFloating(float, true)
        core.state.workspaces.activate("2")
        dropFloat(core)
        #expect(core.state.workspaces.space(of: float) == SpaceID("2"))
    }

    @Test("the drop appends to a Space that holds windows")
    func appendsToAPopulatedSpace() {
        let core = makeCore()
        core.state.setFloating(float, true)
        core.state.workspaces.add(WindowID(2), to: "2")
        dropFloat(core)
        #expect(
            core.state.workspaces["2"]?.windows
                == [WindowID(2), float]
        )
    }

    @Test("the drop reports the move once, from 1 to 2")
    func dropEmitsTheMove() {
        let core = makeCore()
        core.state.setFloating(float, true)
        var moves: [JSONValue] = []
        core.bus.addSink { event, data in
            if event == .windowMovedToSpace { moves.append(data) }
        }
        dropFloat(core)
        #expect(moves.count == 1)
        if case .object(let payload)? = moves.first {
            #expect(payload["from_space_id"] == .string("1"))
            #expect(payload["to_space_id"] == .string("2"))
        }
    }
}
