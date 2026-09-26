import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A flag float dropped by hand on another display joins that
/// display's active Space at the drop (#1686), through the real
/// `handleDragEnd`. Displays are faked through `displayAt`, the
/// `DragCrossingTests` fixture shape; with fake displays no screen
/// resolves, so a re-anchor would stand down on its own and this
/// suite cannot see one — the drop-commit relocate calling none is
/// the guarantee, stated on `relocateDroppedFloat`.
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
        // The pointer placed it: no capture seeded to move it.
        #expect(core.tiler.stashOriginal(float) == nil)
    }

    @Test("a drop on the same display keeps its Space")
    func sameDisplayStays() {
        let core = makeCore(cursorX: 500)
        core.state.setFloating(float, true)
        dropFloat(core)
        #expect(core.state.workspaces.space(of: float) == SpaceID(1))
    }

    @Test("a sticky float keeps its own rules")
    func stickyStays() {
        let core = makeCore(sticky: .display)
        core.state.setFloating(float, true)
        dropFloat(core)
        #expect(core.state.workspaces.space(of: float) == SpaceID(1))
    }

    /// Floating only because of its Space: filing it into the
    /// other display's tiled Space would tile it, so it stays.
    @Test("a floating-mode member stays home")
    func floatingModeMemberStays() {
        let core = makeCore()
        core.state.workspaces.setMode(SpaceID(1), .floating)
        #expect(core.state.windows[float]?.isFloating == false)
        dropFloat(core)
        #expect(core.state.workspaces.space(of: float) == SpaceID(1))
    }
}
