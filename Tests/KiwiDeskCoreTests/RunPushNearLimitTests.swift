import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A press whose weight step the range clamps to less than the screen
/// shows is the weight's limit (#3661): it cues, never moves nothing
/// silently, through the real writers on `RunPushCommandTests`' desk.
extension RunPushCommandTests {
    /// What one press of `points` along `axis` cues, and how far it
    /// moved the focused window.
    private func pressed(
        _ core: KiwiCore,
        _ window: WindowID,
        _ axis: String,
        _ points: Double
    ) -> (refusals: [ResizeRefusal], moved: CGFloat) {
        func length() -> CGFloat {
            let frame = core.tiler.calculatedFrames(state: core.state)[window]
            return (axis == "x" ? frame?.width : frame?.height) ?? 0
        }
        var seen: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { seen.append($0) }
        let before = length()
        press(core, axis, points)
        core.borders.onResizeRefusal = { _ in }
        return (seen, abs(length() - before))
    }

    @Test("Track: a track a hair above its weight's limit cues the limit")
    func trackNearTheLimitCues() {
        let range = TrackLayout.weightRange
        for (weight, step) in [
            (range.upperBound - 0.0003, 5.0),
            (range.lowerBound + 0.0003, -5.0),
        ] {
            let (core, id) = makeSpace(
                "track",
                windows: 2,
                focus: 1,
                width: 4000,
                height: 1000
            ) {
                $0.execute(
                    "track.set_new_window",
                    args: [.string("own_track")]
                )
            }
            core.state.workspaces.withSpace(id) {
                $0.trackWeights[w(1)] = weight
            }
            core.retile(animated: false)
            let result = pressed(core, w(1), "x", step)
            #expect(
                result.refusals == [
                    .ratioLimit(w(1), axis: "x", grows: step > 0)
                ] || result.moved > 0.5,
                Comment(rawValue: "weight \(weight): \(result)")
            )
        }
    }

    @Test("Stack: a zone weight a hair above its floor cues the limit")
    func stackNearTheLimitCues() {
        for height in [1000.0, 1400.0, 2000.0, 4000.0] {
            let (core, id) = makeSpace(
                "stack",
                windows: 3,
                focus: 2,
                height: height
            )
            core.state.workspaces.withSpace(id) {
                $0.stackWeights[w(2)] =
                    StackLayout.weightRange.lowerBound + 0.0003
            }
            core.retile(animated: false)
            let result = pressed(core, w(2), "y", -5)
            // A window the tiny weight leaves at its floor says so.
            #expect(
                !result.refusals.isEmpty || result.moved > 0.5,
                Comment(rawValue: "height \(height): \(result)")
            )
        }
    }
}
