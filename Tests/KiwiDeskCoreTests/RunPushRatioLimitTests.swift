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

    /// The first refusal a hold of `points` presses along `axis`
    /// ends on.
    private func held(
        _ core: KiwiCore,
        _ axis: String,
        _ points: Double
    ) -> ResizeRefusal? {
        var seen: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { seen.append($0) }
        for _ in 0..<600 where seen.isEmpty { press(core, axis, points) }
        core.borders.onResizeRefusal = { _ in }
        return seen.first
    }

    @Test("BSP: the inner window's grow says it grows the other way")
    func bspInnerWindowMovesTheOtherWay() {
        let (core, _) = makeSpace("bsp", windows: 4, focus: 3)
        #expect(
            held(core, "x", 5) == .ratioMovesOtherWay(w(3), axis: "x")
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
