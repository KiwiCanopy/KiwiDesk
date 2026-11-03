import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A press beside a window a push sized, through the real writers
/// (#2709): a drag pushes on the edge it moved, a neighbour's press
/// moves the sized mate's length and never undoes the push, and a
/// length whose zone moved plans nothing. The display, gaps and
/// floor are pinned (#531, #660); `.enabled(if:)` because the
/// writers resolve the Space's screen.
@Suite(
    "Run push beside a sized mate (#2709)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct RunPushMateTests {
    /// `count` windows in one `mode` Space on a 1220 × 820 display
    /// with 10-pt gaps and every bar off, `focus` focused.
    private func makeSpace(
        _ mode: String,
        windows count: UInt32,
        focus: UInt32,
        height: CGFloat = 820,
        setup: (KiwiCore) -> Void = { _ in }
    ) -> (KiwiCore, SpaceID) {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-run-push-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1220, height: height)
        }
        core.tiler.settings.gapsGlobal = Gaps.uniform(10)
        for verb in [
            "space_bar.set_visibility",
            "monocle.set_app_bar_visibility",
            "scroll.set_app_bar_visibility",
        ] {
            core.execute(verb, args: [.string("hidden")])
        }
        #expect(!core.tiler.settings.anyAppBarCanShow)
        #expect(
            core.tiler.settings.minWindowSizes == MinWindowSizes(all: 300)
        )
        core.tiler.animation.isEnabled = false
        core.tiler.settings.mouseResize = .layout
        setup(core)
        for id in UInt32(1)...count {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: pid_t(900_000 + Int32(id)),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute("set_mode", args: [.string(space.raw), .string(mode)])
        core.state.workspaces.focus(WindowID(focus), in: space)
        core.retile(animated: false)
        return (core, space)
    }

    private func press(
        _ core: KiwiCore,
        _ axis: String,
        _ points: Double
    ) {
        core.execute("resize", args: [.string(axis), .number(points)])
        core.retile(animated: false)
    }

    private func hidden(_ core: KiwiCore, _ id: SpaceID) -> Set<WindowID> {
        Set(core.tiler.runCovers[id]?.behind.keys.map { $0 } ?? [])
    }

    private func w(_ raw: UInt32) -> WindowID { WindowID(raw) }

    /// Master w1 beside a stack zone of w2, w3, w4 that holds all
    /// three in 1000 pt, w3 dragged by `edge` 200 pt outward.
    private func dragMiddle(leading: Bool) throws -> (KiwiCore, SpaceID) {
        let (core, id) = makeSpace(
            "stack",
            windows: 4,
            focus: 3,
            height: 1020
        )
        #expect(hidden(core, id).isEmpty)
        let space = try #require(core.state.workspaces[id])
        let slot = try #require(
            core.tiler.calculatedFrames(state: core.state)[w(3)]
        )
        var dragged = slot
        if leading { dragged.origin.y -= 200 }
        dragged.size.height += 200
        core.handleResizeEnd(w(3), slot: slot, frame: dragged, in: space)
        core.retile(animated: false)
        return (core, id)
    }

    @Test("Stack: a drag pushes the neighbour on the edge it moved")
    func dragPushesTheMovedSide() throws {
        let (top, topID) = try dragMiddle(leading: true)
        #expect(hidden(top, topID) == [w(2)])
        #expect(top.state.workspaces[topID]?.runHeads == [w(3)])
        let (bottom, bottomID) = try dragMiddle(leading: false)
        #expect(hidden(bottom, bottomID) == [w(4)])
        #expect(bottom.state.workspaces[bottomID]?.runTails == [w(3)])
    }

    @Test("Stack: a press beside a sized mate moves the mate's length")
    func pressBesideASizedMate() throws {
        let (core, id) = try dragMiddle(leading: true)
        #expect(core.state.workspaces[id]?.runSizes.keys.first == w(3))
        core.state.workspaces.focus(w(4), in: id)
        let before = try #require(
            core.tiler.calculatedFrames(state: core.state)[w(4)]
        )
        press(core, "y", 50)
        let after = try #require(
            core.tiler.calculatedFrames(state: core.state)[w(4)]
        )
        // w4 draws what w3's length leaves: the press moves that
        // length, and w2 stays in the run.
        #expect(abs(after.height - before.height - 50) < 1)
        #expect(core.state.workspaces[id]?.runSizes.keys.first == w(3))
        #expect(core.state.workspaces[id]?.runSizes.count == 1)
        #expect(hidden(core, id) == [w(2)])
    }

    @Test("Stack: a shrink beside a sized mate grows the mate, never pulls")
    func shrinkBesideASizedMate() throws {
        let (core, id) = try dragMiddle(leading: true)
        core.state.workspaces.focus(w(4), in: id)
        let mate = try #require(
            core.tiler.calculatedFrames(state: core.state)[w(3)]
        )
        press(core, "y", -20)
        #expect(hidden(core, id) == [w(2)])
        let grown = try #require(
            core.tiler.calculatedFrames(state: core.state)[w(3)]
        )
        #expect(abs(grown.height - mate.height - 20) < 1)
        // Past its own floor the window stops; nothing joins the run.
        press(core, "y", -400)
        #expect(hidden(core, id) == [w(2)])
        let floor = try #require(
            core.tiler.calculatedFrames(state: core.state)[w(4)]
        )
        #expect(abs(floor.height - 300) < 1)
    }

    @Test("Stack: a grow past the sized mate's room pushes on")
    func growPastTheMateRoomPushes() throws {
        let (core, id) = try dragMiddle(leading: true)
        core.state.workspaces.focus(w(4), in: id)
        press(core, "y", 500)
        // w3 gives all it has and goes into the run; w4 fills.
        #expect(hidden(core, id) == [w(2), w(3)])
        let sizes = core.state.workspaces[id]?.runSizes ?? [:]
        #expect(sizes[w(3)] == nil)
        #expect((sizes[w(4)]?.share ?? 0) == 1)
    }

    @Test("Stack: presses in a run of sized windows move the step they ask")
    func pressesInAnAllSizedRun() throws {
        let (core, id) = makeSpace(
            "stack",
            windows: 4,
            focus: 3,
            height: 1020
        )
        core.state.workspaces.withSpace(id) {
            $0.runSizes = [
                self.w(3): RunSize(share: 0.45, zone: self.w(2)),
                self.w(4): RunSize(share: 0.45, zone: self.w(2)),
            ]
            $0.runHeads = [self.w(3)]
        }
        core.retile(animated: false)
        #expect(hidden(core, id) == [w(2)])
        func height(_ id: UInt32) -> CGFloat {
            core.tiler.calculatedFrames(state: core.state)[w(id)]?.height
                ?? 0
        }
        let sized = height(3)
        press(core, "y", 30)
        #expect(abs(height(3) - sized - 30) < 1)
        // w4 takes what w3 leaves; its press moves w3's length.
        core.state.workspaces.focus(w(4), in: id)
        let rest = height(4)
        press(core, "y", -30)
        #expect(abs(height(4) - rest + 30) < 1)
        #expect(hidden(core, id) == [w(2)])
    }

    @Test("A length whose zone anchor moved is dropped at the next pass")
    func foreignAnchorIsDropped() throws {
        // Four stack windows in 1000 pt: the run hides one at its
        // floors alone, so only the anchor can drop the length.
        let (core, id) = makeSpace(
            "stack",
            windows: 5,
            focus: 3,
            height: 1020
        )
        #expect(hidden(core, id).count == 1)
        core.state.workspaces.withSpace(id) {
            $0.runSizes[self.w(3)] = RunSize(share: 0.6, zone: self.w(9))
        }
        core.retile(animated: false)
        #expect(core.state.workspaces[id]?.runSizes.isEmpty == true)
    }
}
