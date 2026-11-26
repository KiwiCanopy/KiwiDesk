import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The push trigger (owner ruling on #3672, rule (a)): a BSP grow
/// pushes into the overflow only along a chain that already scrolls,
/// and does so with the splits ahead of it keeping their own ratios
/// (#3672) — the chain press is the run's step, never a split's.
extension RunPushCommandTests {
    @Test("BSP: a chain grow pushes and leaves a sized split alone")
    func chainPushKeepsSplitRatios() throws {
        let (core, id) = makeSpace("bsp", windows: 4, focus: 1) {
            $0.execute("bsp.set_strategy", args: [.string("alternating")])
        }
        // w1 sizes its own split first: the one ahead of the chain.
        press(core, "x", 50)
        let sized = core.sessionRatios(of: id).bspSplits
        #expect(sized?.horizontal[w(1)] != nil)
        let run = try #require(core.tiler.runCovers[id]?.runs.first)
        #expect(run.zone.vertical)
        // The chain already scrolls: a `+n` is on screen.
        #expect(!hidden(core, id).isEmpty)
        let shown = run.shown.count
        let focus = try #require(run.shown.first)
        core.state.workspaces.focus(focus, in: id)
        press(core, "y", 400)
        let after = try #require(core.tiler.runCovers[id]?.runs.first)
        #expect(after.shown.count == shown - 1)
        #expect(after.shown.contains(focus))
        #expect(core.sessionRatios(of: id).bspSplits == sized)
    }

    @Test("BSP: with no chain a grow stops at the neighbour's floor")
    func noChainStopsAtTheFloor() {
        // 2560 × 1440 fits all four: no `+n`, so nothing is pushed.
        let (core, id) = makeSpace(
            "bsp",
            windows: 4,
            focus: 3,
            width: 2560,
            height: 1440
        ) { $0.execute("bsp.set_strategy", args: [.string("alternating")]) }
        #expect(core.tiler.runCovers[id]?.runs.isEmpty ?? true)
        var seen: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { seen.append($0) }
        for _ in 0..<40 { press(core, "x", 50) }
        #expect(core.tiler.runCovers[id]?.runs.isEmpty ?? true)
        #expect(
            seen.last
                == .neighborMinimum(
                    anchor: w(4),
                    focused: w(3),
                    axis: "x",
                    appBound: false,
                    anchorApp: "App4"
                )
        )
    }
}
