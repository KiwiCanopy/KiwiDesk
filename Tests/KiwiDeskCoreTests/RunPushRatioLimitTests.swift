import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A press a ratio or weight stops names that limit, not a window
/// minimum the window has not reached (#3643), through the real
/// writers on `RunPushCommandTests`' desk.
extension RunPushCommandTests {
    /// The refusals one press of `points` along `axis` cues.
    private func refusals(
        _ core: KiwiCore,
        _ axis: String,
        _ points: Double
    ) -> [ResizeRefusal] {
        var seen: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { seen.append($0) }
        press(core, axis, points)
        core.borders.onResizeRefusal = { _ in }
        return seen
    }

    /// The inner window of a nested pair is about r(1 − r) of the
    /// width, one ratio dividing every level.
    private func innerWindow(ratio: Double) -> KiwiCore {
        makeSpace("bsp", windows: 4, focus: 3, width: 2560, height: 1440) {
            $0.execute("bsp.set_ratio_h", args: [.number(ratio)])
        }.0
    }

    @Test("BSP: below the peak the inner window grows the other way")
    func bspInnerWindowMovesTheOtherWay() {
        #expect(
            refusals(innerWindow(ratio: 0.4), "x", 5) == [
                .ratioMovesOtherWay(w(3), axis: "x", grows: true)
            ]
        )
        #expect(
            refusals(innerWindow(ratio: 0.4), "x", -5) == [
                .ratioMovesOtherWay(w(3), axis: "x", grows: false)
            ]
        )
    }

    @Test("BSP: at the peak the inner window's grow is the largest share")
    func bspInnerWindowAtThePeak() {
        #expect(
            refusals(innerWindow(ratio: 0.5), "x", 5) == [
                .ratioLimit(w(3), axis: "x", grows: true)
            ]
        )
    }

    @Test("BSP: a ratio at its stored bound says the share is spent")
    func bspRatioAtItsBound() {
        for (ratio, step, grows) in [(0.9, 5.0, true), (0.1, -5.0, false)] {
            let (core, _) = makeSpace(
                "bsp",
                windows: 6,
                focus: 1,
                width: 4000,
                height: 4000
            ) { core in
                core.execute("bsp.set_ratio_h", args: [.number(ratio)])
            }
            #expect(
                refusals(core, "x", step) == [
                    .ratioLimit(w(1), axis: "x", grows: grows)
                ],
                Comment(rawValue: "ratio \(ratio)")
            )
        }
    }

    @Test("Track: a track weight at its limit says the share is spent")
    func trackWeightAtItsLimit() {
        let range = TrackLayout.weightRange
        for (weight, step, grows) in [
            (range.upperBound, 5.0, true),
            (range.lowerBound, -5.0, false),
        ] {
            let (core, id) = makeSpace(
                "track",
                windows: 2,
                focus: 1,
                width: 4000,
                height: 1000
            ) { core in
                core.execute(
                    "track.set_new_window",
                    args: [.string("own_track")]
                )
            }
            core.state.workspaces.withSpace(id) {
                $0.trackWeights[w(1)] = weight
            }
            core.retile(animated: false)
            #expect(
                refusals(core, "x", step) == [
                    .ratioLimit(w(1), axis: "x", grows: grows)
                ],
                Comment(rawValue: "weight \(weight)")
            )
        }
    }

    @Test("Stack: a window at its floor says so at the weight's limit too")
    func stackFloorWinsOverTheLimit() {
        // The stack zone's two 300-pt floors and three 10-pt gaps
        // fill 630 exactly.
        let (core, id) = makeSpace(
            "stack",
            windows: 3,
            focus: 2,
            height: 630
        )
        core.state.workspaces.withSpace(id) {
            $0.stackWeights[w(2)] = StackLayout.weightRange.lowerBound
        }
        core.retile(animated: false)
        #expect(
            refusals(core, "y", -5) == [
                .ownMinimum(w(2), axis: "y", appBound: false)
            ]
        )
    }

    @Test("Stack: a shrink at the weight's floor says the share is spent")
    func stackWeightAtItsFloor() {
        let (core, id) = makeSpace(
            "stack",
            windows: 3,
            focus: 2,
            height: 4000
        )
        core.state.workspaces.withSpace(id) {
            $0.stackWeights[w(2)] = StackLayout.weightRange.lowerBound
        }
        core.retile(animated: false)
        #expect(
            refusals(core, "y", -5) == [
                .ratioLimit(w(2), axis: "y", grows: false)
            ]
        )
    }
}
