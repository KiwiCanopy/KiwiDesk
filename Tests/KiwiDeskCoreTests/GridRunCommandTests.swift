import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A Grid's scrolled last track through the real dispatch (#2541):
/// a focus key steps into its hidden windows, an auto-sized run
/// takes a press along it as a run weight, and entering Grid drops
/// a Stack session's weights. The display, gaps and floor are
/// pinned (#531, #660).
@Suite(
    "Grid run commands (#2541)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct GridRunCommandTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-grid-run-\(UUID().uuidString)"
                )
        )
        // 1220 × 820 less 10-pt outer gaps leaves 1200 × 800 with
        // 20-pt inner gaps: a 3 × 2 grid at 300 pt fits.
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1220, height: 820)
        }
        core.tiler.settings.gapsGlobal = Gaps(
            outer: Gaps.Outer(top: 10, bottom: 10, left: 10, right: 10),
            inner: Gaps.Inner(horizontal: 20, vertical: 20)
        )
        #expect(
            core.tiler.settings.minWindowSizes == MinWindowSizes(all: 300)
        )
        core.tiler.animation.isEnabled = false
        return core
    }

    /// Nine windows in a rigid 3 × 2 grid, window `focus` focused:
    /// the last row shows 4…6 and parks 7…9.
    @discardableResult
    private func grid(
        _ core: KiwiCore,
        focus: UInt32,
        autoSize: Bool = false
    ) -> SpaceID {
        core.execute("grid.set_type", args: [.string("rigid")])
        core.execute(
            "grid.set_dimensions",
            args: [.number(3), .number(2)]
        )
        core.execute("grid.set_auto_size", args: [.bool(autoSize)])
        for id in UInt32(1)...9 {
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
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("grid")]
        )
        core.state.workspaces.focus(WindowID(focus), in: space)
        core.retile(animated: false)
        return space
    }

    @Test("A focus key steps into the last track's hidden windows")
    func focusStepsIntoTheRun() throws {
        let core = makeCore()
        let id = grid(core, focus: 6)
        let run = try #require(core.tiler.runCovers[id]?.runs.first)
        // Step off whichever end of the run hides windows.
        let (from, key, expected) =
            run.hiddenAfter.isEmpty
            ? (run.shown.first, "left", run.hiddenBefore.last)
            : (run.shown.last, "right", run.hiddenAfter.first)
        let origin = try #require(from)
        let target = try #require(expected)
        core.state.workspaces.focus(origin, in: id)
        #expect(
            core.execute("focus", args: [.string(key)]).isSuccess
        )
        #expect(core.activeSpace?.focused == target)
    }

    @Test("A press along an auto-sized run moves its weights")
    func autoSizedRunTakesRunWeights() throws {
        let core = makeCore()
        let id = grid(core, focus: 4, autoSize: true)
        let run = try #require(core.tiler.runCovers[id]?.runs.first)
        #expect(run.shown.contains(WindowID(4)))
        #expect(run.extra > 0)
        let columns = core.state.workspaces[id]?.sessionRatios
        #expect(
            core.execute(
                "resize",
                args: [.string("x"), .number(50)]
            ).isSuccess
        )
        let space = try #require(core.state.workspaces[id])
        #expect(space.stackWeights[WindowID(4)] != nil)
        // The grid's own column weights stay where they were.
        #expect(space.sessionRatios == columns)
    }

    @Test("Entering Grid drops a Stack session's weights")
    func gridEntryClearsStackWeights() throws {
        let core = makeCore()
        let id = grid(core, focus: 1)
        core.execute(
            "set_mode",
            args: [.string(id.raw), .string("stack")]
        )
        core.state.workspaces.withSpace(id) {
            $0.stackWeights[WindowID(5)] = 3
        }
        core.execute(
            "set_mode",
            args: [.string(id.raw), .string("grid")]
        )
        #expect(core.state.workspaces[id]?.stackWeights.isEmpty == true)
    }

    @Test("Leaving Grid drops its run's weights")
    func gridExitClearsRunWeights() throws {
        let core = makeCore()
        let id = grid(core, focus: 1)
        core.state.workspaces.withSpace(id) {
            $0.stackWeights[WindowID(7)] = 3
        }
        core.execute(
            "set_mode",
            args: [.string(id.raw), .string("stack")]
        )
        #expect(core.state.workspaces[id]?.stackWeights.isEmpty == true)
    }
}
