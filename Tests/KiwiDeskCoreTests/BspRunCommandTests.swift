import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A BSP chain's run through the real dispatch (#2542): a focus key
/// steps into its hidden windows, a press along it moves run
/// weights rather than a ratio, and the split floor heal reads no
/// parked window. The display, gaps and floor are pinned (#531,
/// #660).
@Suite(
    "BSP run commands (#2542)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct BspRunCommandTests {
    /// Four windows over 1000 × 720 at 10-pt gaps, alternating:
    /// w1 stays left, and the vertical chain w2…w4 shows two and
    /// parks the third.
    private func makeCore(focus: UInt32) -> (KiwiCore, SpaceID) {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-bsp-run-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1000, height: 720)
        }
        core.tiler.settings.gapsGlobal = Gaps.uniform(10)
        // No shelf strip, so the pinned rect is the layout's.
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
        core.execute("bsp.set_strategy", args: [.string("alternating")])
        for id in UInt32(1)...4 {
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
            args: [.string(space.raw), .string("bsp")]
        )
        core.state.workspaces.focus(WindowID(focus), in: space)
        core.retile(animated: false)
        return (core, space)
    }

    @Test("A focus key steps into the chain's hidden window")
    func focusStepsIntoTheRun() throws {
        let (core, id) = makeCore(focus: 3)
        let run = try #require(core.tiler.runCovers[id]?.runs.first)
        #expect(run.zone.vertical)
        // Step off whichever end of the run hides a window.
        let (from, key, expected) =
            run.hiddenAfter.isEmpty
            ? (run.shown.first, "up", run.hiddenBefore.last)
            : (run.shown.last, "down", run.hiddenAfter.first)
        let origin = try #require(from)
        let target = try #require(expected)
        core.state.workspaces.focus(origin, in: id)
        #expect(
            core.execute("focus", args: [.string(key)]).isSuccess
        )
        #expect(core.activeSpace?.focused == target)
    }

    @Test("A press along the chain moves its weights, not a ratio")
    func pressAlongTheChainTakesRunWeights() throws {
        let (core, id) = makeCore(focus: 2)
        let run = try #require(core.tiler.runCovers[id]?.runs.first)
        #expect(run.extra > 0)
        let before = try #require(core.state.workspaces[id])
        let ratio = core.tiler.settings.resolvedBsp(for: before)
            .splitRatioV
        #expect(
            core.execute(
                "resize",
                args: [.string("y"), .number(40)]
            ).isSuccess
        )
        let space = try #require(core.state.workspaces[id])
        #expect(space.stackWeights[WindowID(2)] != nil)
        #expect(
            core.tiler.settings.resolvedBsp(for: space).splitRatioV
                == ratio
        )
    }

    @Test("The split floor heal reads no parked window")
    func healSkipsTheParkedWindow() throws {
        let (core, id) = makeCore(focus: 2)
        // A tall floor on the parked w4 would move the stacked
        // ratio for a window no ratio places.
        let w4 = WindowID(4)
        for step in [CGFloat(60), CGFloat(110)] {
            for _ in 0..<2 {
                core.tiler.boundLearner.recordAsk(
                    w4,
                    size: CGSize(width: 585, height: 500 - step)
                )
                core.tiler.boundLearner.observe(
                    w4,
                    currentSize: CGSize(width: 585, height: 500),
                    settledRead: true
                )
            }
        }
        #expect(core.tiler.sizeBound(for: w4)?.minHeight == 500)
        core.retile(animated: false)
        let run = try #require(core.tiler.runCovers[id]?.runs.first)
        #expect(run.hiddenAfter.contains(w4))
        let space = try #require(core.state.workspaces[id])
        #expect(
            core.tiler.settings.resolvedBsp(for: space).splitRatioV
                == 0.5
        )
    }
}
