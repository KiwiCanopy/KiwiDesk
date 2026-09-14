import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The split heal's unfit arm (#934, owner rulings 2026-08-31 and
/// 2026-09-14): where a same-axis neighbour already sits at its
/// own floor the engine says so ONCE per episode, with the
/// neighbour-minimum pill on the overhanging window, re-arms when
/// the window fits again or its bound is forgotten, and the
/// overflow lands inward. The heal's happy path is
/// `SplitFloorHealWiringTests`. Display and `min_window_size`
/// pinned (#531, #660).
@Suite("Split floor unfit cue & inward overflow (#934)", .serialized)
@MainActor
struct SplitFloorCueTests {
    private func makeCore(mode: String) -> (KiwiCore, SpaceID) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-split-cue-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        #expect(core.tiler.settings.minWindowSize == 300)
        for id in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string(mode)]
        )
        core.state.workspaces.focus(WindowID(1), in: space)
        return (core, space)
    }

    /// A corroborated `minWidth` floor: two distinct asks, each
    /// refused twice with the same answer.
    private func seed(
        _ core: KiwiCore,
        window: WindowID,
        minWidth: CGFloat
    ) {
        for asked in [minWidth - 60, minWidth - 110] {
            for _ in 0..<2 {
                core.tiler.boundLearner.recordAsk(
                    window,
                    size: CGSize(width: asked, height: 385)
                )
                core.tiler.boundLearner.observe(
                    window,
                    currentSize: CGSize(width: minWidth, height: 385),
                    settledRead: true
                )
            }
        }
    }

    @Test("Two floors the split cannot hold cue once, and re-arm")
    func unfitCuesOnceAndReArms() {
        guard NSScreen.main != nil else { return }
        let (core, space) = makeCore(mode: "bsp")
        let w1 = WindowID(1)
        let w2 = WindowID(2)
        // 700 + 700 exceeds the 1170 pt split: both sink at 0.5,
        // the low side overhangs and the high side binds.
        seed(core, window: w1, minWidth: 700)
        seed(core, window: w2, minWidth: 700)
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.retile()
        #expect(
            refusals == [
                .neighborMinimum(anchor: w2, focused: w1, axis: "x")
            ]
        )
        let ratio = core.tiler.settings.resolvedBsp(
            for: core.state.workspaces[space]!
        ).splitRatioH
        #expect(ratio == 0.5)
        // Once per episode: a retile storm says nothing more.
        core.retile()
        core.retile()
        #expect(refusals.count == 1)
        // The neighbour's bound is forgotten: the split now fits
        // w1's floor, the heal moves the ratio and the episode
        // ends.
        core.tiler.forgetSizeBound(w2)
        core.retile()
        #expect(refusals.count == 1)
        let healed = core.tiler.settings.resolvedBsp(
            for: core.state.workspaces[space]!
        ).splitRatioH
        #expect(abs(healed * 1170 - 700.25) < 0.01)
        // Re-learned: a new episode, a new cue — this time the
        // healed low side holds its floor and binds.
        seed(core, window: w2, minWidth: 700)
        core.retile()
        #expect(refusals.count == 2)
        #expect(
            refusals.last
                == .neighborMinimum(anchor: w1, focused: w2, axis: "x")
        )
    }

    @Test("An unfit bsp floor lands inward, never past the edge")
    func unfitBspLandsInward() throws {
        guard NSScreen.main != nil else { return }
        let (core, _) = makeCore(mode: "bsp")
        seed(core, window: WindowID(1), minWidth: 700)
        seed(core, window: WindowID(2), minWidth: 700)
        core.retile()
        // The frames the retile ISSUES carry the residue; the
        // slots every reader classifies against stay the
        // layout's own.
        let frames = core.tiler.placedFrames(state: core.state)
        let left = try #require(frames[WindowID(1)])
        let slots = core.tiler.calculatedFrames(state: core.state)
        #expect(try #require(slots[WindowID(1)]).width < 600)
        let right = try #require(frames[WindowID(2)])
        #expect(left.width == 700)
        #expect(left.minX == 10)
        #expect(right.width == 700)
        #expect(abs(right.maxX - 1190) < 0.01)
    }

    @Test("An unfit stack floor cues on the zone that overhangs")
    func unfitStackCuesAndLandsInward() throws {
        guard NSScreen.main != nil else { return }
        let (core, space) = makeCore(mode: "stack")
        let w1 = WindowID(1)
        let w2 = WindowID(2)
        // Master draws 702 at the 0.6 default and holds a 700
        // floor; the 468 pt stack zone cannot hold its own.
        seed(core, window: w1, minWidth: 700)
        seed(core, window: w2, minWidth: 700)
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.retile()
        #expect(
            refusals == [
                .neighborMinimum(anchor: w1, focused: w2, axis: "x")
            ]
        )
        #expect(
            core.tiler.settings.resolvedStack(
                for: core.state.workspaces[space]!
            ).masterRatio == 0.6
        )
        let frame = try #require(
            core.tiler.placedFrames(state: core.state)[w2]
        )
        #expect(frame.width == 700)
        #expect(abs(frame.maxX - 1190) < 0.01)
    }
}
