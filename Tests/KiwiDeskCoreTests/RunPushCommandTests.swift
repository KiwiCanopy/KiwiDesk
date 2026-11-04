import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A resize along a run through the real writers (#2709): the
/// keyboard `resize` and the mouse drop push the squeezed neighbour
/// into the run and a shrink pulls it back, in every layout that
/// scrolls one — Stack's zones, Track's tracks, an auto-sized
/// Grid's last track and BSP's chain — while a fixed Grid's last
/// row keeps its column lines. The display, gaps and floor are
/// pinned (#531, #660). `.enabled(if:)` because the writers resolve
/// the Space's screen.
@Suite(
    "Run push commands (#2709)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct RunPushCommandTests {
    /// `count` windows in one `mode` Space on a 1220 × 820 display
    /// with 10-pt gaps and every bar off, `focus` focused.
    private func makeSpace(
        _ mode: String,
        windows count: UInt32,
        focus: UInt32,
        width: CGFloat = 1220,
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
            CGRect(x: 0, y: 0, width: width, height: height)
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

    @Test("Stack: a grow pushes the zone mate in, a shrink pulls it back")
    func stackPushAndPull() throws {
        // Master w1 beside the stack zone w2, w3: two 300-pt floors
        // in 800 pt, so w2 grown by 300 leaves w3 no room.
        let (core, id) = makeSpace("stack", windows: 3, focus: 2)
        #expect(hidden(core, id).isEmpty)
        press(core, "y", 300)
        #expect(hidden(core, id) == [w(3)])
        let grown = try #require(
            core.tiler.calculatedFrames(state: core.state)[w(2)]
        )
        // Alone in the zone, w2 took w3's room as well: a shrink
        // that leaves w3 its floor brings it back.
        #expect(grown.height > 700)
        press(core, "y", -10)
        let frames = core.tiler.calculatedFrames(state: core.state)
        let kept = try #require(frames[w(2)])
        let back = try #require(frames[w(3)])
        #expect(abs(back.height - 300) < 1)
        #expect(kept.height > back.height)
        #expect(hidden(core, id).isEmpty)
        #expect(core.state.workspaces[id]?.runTails.isEmpty == true)
        // Every window shows again, so the length plans nothing and
        // the store drops it.
        #expect(core.state.workspaces[id]?.runSizes.isEmpty == true)
    }

    @Test("Stack: dragging the leading edge pushes the window before it")
    func stackDragPushesTheStart() throws {
        let (core, id) = makeSpace("stack", windows: 3, focus: 3)
        let space = try #require(core.state.workspaces[id])
        let slot = try #require(
            core.tiler.calculatedFrames(state: core.state)[w(3)]
        )
        var dragged = slot
        dragged.origin.y -= 300
        dragged.size.height += 300
        core.handleResizeEnd(w(3), slot: slot, frame: dragged, in: space)
        core.retile(animated: false)
        #expect(hidden(core, id) == [w(2)])
        #expect(core.state.workspaces[id]?.runHeads == [w(3)])
    }

    @Test("Track: a grow along the track pushes the track mate in")
    func trackPush() throws {
        let (core, id) = makeSpace("track", windows: 3, focus: 2) {
            $0.execute("track.set_new_window", args: [.string("own_track")])
        }
        core.state.workspaces.withSpace(id) {
            // Two tracks: [1] [2, 3].
            $0.trackBreaks = [self.w(1), self.w(2)]
        }
        core.retile(animated: false)
        #expect(hidden(core, id).isEmpty)
        let vertical =
            core.tiler.settings.resolvedTrack(for: id).axis == .vertical
        press(core, vertical ? "y" : "x", 400)
        #expect(hidden(core, id) == [w(3)])
        #expect(core.state.workspaces[id]?.trackWeights.isEmpty == true)
    }

    @Test("Auto-sized Grid: a grow along the last row pushes its mate")
    func autoGridPush() throws {
        let (core, id) = makeSpace("grid", windows: 9, focus: 5) {
            $0.execute("grid.set_type", args: [.string("rigid")])
            $0.execute(
                "grid.set_dimensions",
                args: [.number(3), .number(2)]
            )
            $0.execute("grid.set_auto_size", args: [.bool(true)])
        }
        let before = hidden(core, id)
        #expect(!before.isEmpty)
        let run = try #require(core.tiler.runCovers[id]?.runs.first)
        #expect(run.shown.contains(w(5)))
        let shown = run.shown.count
        press(core, "x", 400)
        let after = try #require(core.tiler.runCovers[id]?.runs.first)
        #expect(after.shown.count == shown - 1)
        #expect(after.shown.contains(w(5)))
        #expect(core.state.workspaces[id]?.runSizes[w(5)] != nil)
    }

    @Test("Auto-sized Grid: a last row that fits whole pushes too")
    func autoGridFittingRowPushes() throws {
        let (core, id) = makeSpace(
            "grid",
            windows: 9,
            focus: 5,
            width: 2560
        ) {
            $0.execute("grid.set_type", args: [.string("rigid")])
            $0.execute(
                "grid.set_dimensions",
                args: [.number(3), .number(2)]
            )
            $0.execute("grid.set_auto_size", args: [.bool(true)])
        }
        // w1's learned 800 caps the columns at three, so w4…w9 run
        // along a last row that holds them all at their floors.
        let answer = CGSize(width: 800, height: 385)
        for step in [CGFloat(60), CGFloat(110)] {
            for _ in 0..<2 {
                core.tiler.boundLearner.recordAsk(
                    w(1),
                    size: CGSize(width: 800 - step, height: 385)
                )
                core.tiler.boundLearner.observe(
                    w(1),
                    currentSize: answer,
                    settledRead: true
                )
            }
        }
        core.retile(animated: false)
        let space = try #require(core.state.workspaces[id])
        let screen = try #require(
            TilingEngine.screen(for: id, in: core.state)
        )
        let input = core.tiler.layoutInput(
            state: core.state,
            space: space,
            screen: screen
        )
        let zone = try #require(
            GridLayout.zones(for: input.tiled, in: input.context)?.first
        )
        #expect(zone.run(in: input.context) == nil)
        #expect(hidden(core, id).isEmpty)
        press(core, "x", 2000)
        #expect(!hidden(core, id).isEmpty)
        #expect(core.state.workspaces[id]?.runSizes[w(5)] != nil)
    }

    @Test("Fixed Grid: the last row keeps its cells, nothing is pushed")
    func fixedGridKeepsItsColumns() throws {
        let (core, id) = makeSpace("grid", windows: 9, focus: 5) {
            $0.execute("grid.set_type", args: [.string("rigid")])
            $0.execute(
                "grid.set_dimensions",
                args: [.number(3), .number(2)]
            )
            $0.execute("grid.set_auto_size", args: [.bool(false)])
        }
        let before = try #require(core.tiler.runCovers[id]?.runs.first)
        press(core, "x", 400)
        let after = try #require(core.tiler.runCovers[id]?.runs.first)
        #expect(after.shown == before.shown)
        #expect(core.state.workspaces[id]?.runSizes.isEmpty == true)
    }

    @Test("BSP: a grow along the chain pushes the chain mate in")
    func bspChainPush() throws {
        let (core, id) = makeSpace("bsp", windows: 4, focus: 2) {
            $0.execute("bsp.set_strategy", args: [.string("alternating")])
        }
        let run = try #require(core.tiler.runCovers[id]?.runs.first)
        #expect(run.zone.vertical)
        let shown = run.shown.count
        #expect(shown >= 2)
        let focus = try #require(run.shown.first)
        core.state.workspaces.focus(focus, in: id)
        let ratio = core.tiler.settings.resolvedBsp(
            for: try #require(core.state.workspaces[id]),
            session: core.sessionRatios(of: id)
        ).splitRatioH
        // The writer, without the dispatcher's retile: the write
        // itself stores the length and the ends.
        _ = core.resizeBspChain(
            focus,
            axis: "y",
            delta: 400,
            space: try #require(core.state.workspaces[id]),
            toward: .both
        )
        let written = try #require(core.state.workspaces[id])
        #expect(written.runSizes[focus] != nil)
        #expect(written.runTails.contains(focus))
        core.retile(animated: false)
        let after = try #require(core.tiler.runCovers[id]?.runs.first)
        #expect(after.shown.count == shown - 1)
        #expect(after.shown.contains(focus))
        // The halved part keeps its ratio.
        #expect(
            core.tiler.settings.resolvedBsp(
                for: try #require(core.state.workspaces[id]),
                session: core.sessionRatios(of: id)
            ).splitRatioH == ratio
        )
    }

    @Test("A zone that fits whole cues a press its weight's limit stops")
    func spentWeightInAWholeZoneCues() throws {
        // 4000 pt keeps w3 above its floor even at w2's limit, so the
        // zone lays whole, with no run for a press to step.
        let (core, id) = makeSpace(
            "stack",
            windows: 3,
            focus: 2,
            height: 4000
        )
        core.state.workspaces.withSpace(id) {
            $0.stackWeights[w(2)] = StackLayout.weightRange.upperBound
        }
        core.retile(animated: false)
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        press(core, "y", 5)
        #expect(refusals.count == 1)
    }

    @Test("A hold stops short of a push, and the next press pushes")
    func holdStopsShortOfPush() throws {
        let (core, id) = makeSpace("stack", windows: 3, focus: 2)
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        // A glide step that would push w3.
        core.keys.holdGlide.isGliding = true
        core.keys.holdGlide.isApplyingGlideStep = true
        press(core, "y", 300)
        core.keys.holdGlide.isApplyingGlideStep = false
        #expect(hidden(core, id).isEmpty)
        #expect(!core.keys.isGliding)
        #expect(refusals.isEmpty)
        let frames = core.tiler.calculatedFrames(state: core.state)
        let mate = try #require(frames[w(3)])
        #expect(abs(mate.height - 300) < 1)
        // The press after it pushes.
        press(core, "y", 5)
        #expect(hidden(core, id) == [w(3)])
        #expect(refusals.isEmpty)
    }

    @Test("A mode change drops the run sizes")
    func modeWriteClearsRunSizes() throws {
        let (core, id) = makeSpace("stack", windows: 3, focus: 2)
        press(core, "y", 300)
        #expect(core.state.workspaces[id]?.runSizes.isEmpty == false)
        // The mode write itself, ahead of any pass's persist.
        core.state.workspaces.setMode(id, .track)
        #expect(core.state.workspaces[id]?.runSizes.isEmpty == true)
    }
}
