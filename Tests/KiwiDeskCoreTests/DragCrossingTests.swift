import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The live cross-display make-room move (#504) at the KiwiCore
/// level: membership eager-moves on a crossing, reverts on an
/// abnormal cancel, and the drop path ends the gesture. Displays
/// are faked through the injected `displayAt`, so no real second
/// monitor (or any screen) is needed — the crossing acts on
/// state, not geometry.
@Suite("Drag display crossing", .serialized)
@MainActor
struct DragCrossingTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-crossing-\(UUID().uuidString)"
                )
        )
    }

    private func addWindow(
        _ core: KiwiCore,
        _ raw: UInt32
    ) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(raw),
                    pid: 1,
                    appName: "App\(raw)"
                )
            )
        )
    }

    /// Two displays: the default space "1" (with windows 1, 2)
    /// on display 1, an empty space "2" on display 2. The drag
    /// machinery believes the mouse is pressed.
    private func makeTwoDisplayCore() -> KiwiCore {
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)
        core.state.workspaces.assign(
            SpaceID(1),
            to: DisplayID(1)
        )
        core.state.workspaces.assign("2", to: DisplayID(2))
        core.drag.isMousePressed = { true }
        core.drag.cursorLocation = { CGPoint(x: 1500, y: 100) }
        // Fake topology replaces the NSScreen lookup for BOTH
        // the crossing and the drop-commit relocate: left half
        // is display 1, right half display 2 — otherwise a real
        // screen whose id collides with the fixture's would let
        // `relocateAcrossDisplay` act during the drop tests.
        core.dragCrossing.displayAt = { point in
            point.x < 1000 ? DisplayID(1) : DisplayID(2)
        }
        return core
    }

    @Test("A crossing eager-moves membership and follows focus")
    func crossingMovesMembership() {
        let core = makeTwoDisplayCore()
        let id = WindowID(1)
        // The wired onCross is the debounced dwell's landing
        // point — fire it directly, as the coordinator would.
        core.dragCrossing.onCross(id, DisplayID(2))
        #expect(
            core.state.workspaces.space(of: id) == SpaceID("2")
        )
        #expect(
            core.state.workspaces[SpaceID(1)]?.windows
                == [WindowID(2)]
        )
        // The focused display followed the drag (#446); the
        // moved window is the destination's focus.
        #expect(core.activeSpace?.id == SpaceID("2"))
        #expect(core.activeSpace?.focused == id)
        // The gesture knows it crossed — the drop path's
        // resize-gate bypass reads exactly this.
        #expect(core.dragCrossing.hasCrossed(id))
        #expect(
            core.dragCrossing.origin(for: id)?.space
                == SpaceID(1)
        )
        #expect(core.dragCrossing.origin(for: id)?.index == 0)
        // The window stays pinned under the cursor: exempt from
        // re-framing for the rest of the gesture.
        #expect(core.tiler.dragExemptWindow == id)
    }

    @Test("A release during the dwell leaves membership alone")
    func releasedDwellIsIgnored() {
        let core = makeTwoDisplayCore()
        core.drag.isMousePressed = { false }
        let id = WindowID(1)
        // The dwell fired after the release: the drop-commit
        // relocate (#492) owns the gesture now.
        core.dragCrossing.onCross(id, DisplayID(2))
        #expect(
            core.state.workspaces.space(of: id) == SpaceID(1)
        )
        #expect(core.dragCrossing.hasCrossed(id) == false)
    }

    @Test("An abnormal cancel restores the origin space + index")
    func cancelReverts() {
        let core = makeTwoDisplayCore()
        let id = WindowID(2)
        core.dragCrossing.onCross(id, DisplayID(2))
        #expect(
            core.state.workspaces.space(of: id) == SpaceID("2")
        )
        // Window closed / rekeyed mid-drag: the gesture never
        // reaches handleDragEnd.
        core.cancelDrag(id)
        #expect(
            core.state.workspaces.space(of: id) == SpaceID(1)
        )
        #expect(
            core.state.workspaces[SpaceID(1)]?.windows
                == [WindowID(1), WindowID(2)]
        )
        // Bookkeeping is gone — a reused id starts clean.
        #expect(core.dragCrossing.origin(for: id) == nil)
        #expect(core.dragCrossing.hasCrossed(id) == false)
    }

    @Test("The drop ends the gesture and reports the crossing")
    func dropEndsGesture() {
        let core = makeTwoDisplayCore()
        let id = WindowID(1)
        core.dragCrossing.onCross(id, DisplayID(2))
        #expect(core.dragCrossing.hasCrossed(id))
        // The real drop runs handleDragEnd, which must both
        // read the crossing (resize bypass) and clear it.
        core.handleDragEnd(
            id,
            start: CGRect(x: 0, y: 0, width: 500, height: 500),
            frame: CGRect(x: 1400, y: 50, width: 400, height: 400)
        )
        #expect(core.dragCrossing.hasCrossed(id) == false)
        #expect(core.dragCrossing.origin(for: id) == nil)
        // Size changed mid-gesture (the smaller-display clamp),
        // yet the window stays MOVED — never re-interpreted as
        // a resize snapping it home (#492's gotcha, live).
        #expect(
            core.state.workspaces.space(of: id) == SpaceID("2")
        )
    }

    @Test("A stale dwell fire is dropped when the cursor left")
    func staleFireRevalidatesCursor() {
        let core = makeTwoDisplayCore()
        // AX move events can lag the pointer by more than the
        // dwell (Electron): by fire time the cursor is back on
        // the home display — the fire must not commit.
        core.drag.cursorLocation = { CGPoint(x: 100, y: 100) }
        let id = WindowID(1)
        core.dragCrossing.onCross(id, DisplayID(2))
        #expect(
            core.state.workspaces.space(of: id) == SpaceID(1)
        )
        #expect(core.dragCrossing.hasCrossed(id) == false)
    }

    @Test("An armed Space Bar target blocks the dwell fire")
    func armedBarBlocksFire() throws {
        let core = makeTwoDisplayCore()
        let id = WindowID(1)
        // Arm a bar target through the coordinator's own API: a
        // hit over a foreign space's item arms synchronously.
        core.spaceBarDrop.hitTest = { _ in SpaceID("9") }
        core.spaceBarDrop.currentSpace = { _ in SpaceID(1) }
        core.spaceBarDrop.moved(id, cursor: .zero)
        try #require(core.spaceBarDrop.isArmed)
        // The bar spring is a competing membership mover; an
        // armed target wins over a racing dwell fire.
        core.dragCrossing.onCross(id, DisplayID(2))
        #expect(
            core.state.workspaces.space(of: id) == SpaceID(1)
        )
        #expect(core.dragCrossing.hasCrossed(id) == false)
    }

    @Test("A native-tab rekey reverts under the new id")
    func rekeyTransfersRevert() {
        let core = makeTwoDisplayCore()
        let old = WindowID(1)
        let new = WindowID(9)
        core.dragCrossing.onCross(old, DisplayID(2))
        #expect(
            core.state.workspaces.space(of: old) == SpaceID("2")
        )
        // The state fold swaps the id in place (#308), then the
        // event handler transfers the crossing bookkeeping,
        // cancels the old gesture, and reverts under the new id
        // — the exact wiring in KiwiCore+Events.
        core.state.apply(.windowRekeyed(old, new))
        core.dragCrossing.rekey(old: old, new: new)
        core.cancelDrag(old)
        core.revertLiveCrossing(new)
        #expect(
            core.state.workspaces.space(of: new) == SpaceID(1)
        )
        #expect(core.dragCrossing.origin(for: new) == nil)
        #expect(core.dragCrossing.origin(for: old) == nil)
    }

    @Test("A marked sticky refusal blocks later crossings")
    func stickyRefusalBlocks() {
        let core = makeTwoDisplayCore()
        let id = WindowID(1)
        core.dragCrossing.markStickyRefused(id)
        core.dragCrossing.onCross(id, DisplayID(2))
        #expect(
            core.state.workspaces.space(of: id) == SpaceID(1)
        )
    }

    @Test("insertDropped lands on the target's index")
    func insertDroppedOnTarget() {
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)
        addWindow(core, 3)
        core.state.workspaces.assign("B", to: DisplayID(2))
        core.state.workspaces.add(WindowID(2), to: "B")
        core.state.workspaces.add(WindowID(3), to: "B")
        // The shared placement choke point (#492 / #504): onto a
        // member window → its index, target shifts down.
        core.insertDropped(
            WindowID(1),
            onto: WindowID(3),
            into: "B"
        )
        #expect(
            core.state.workspaces[SpaceID("B")]?.windows
                == [WindowID(2), WindowID(1), WindowID(3)]
        )
    }

    @Test("insertDropped with no target appends")
    func insertDroppedAppends() {
        let core = makeCore()
        addWindow(core, 1)
        core.state.workspaces.assign("B", to: DisplayID(2))
        core.insertDropped(WindowID(1), onto: nil, into: "B")
        #expect(
            core.state.workspaces[SpaceID("B")]?.windows
                == [WindowID(1)]
        )
    }
}
