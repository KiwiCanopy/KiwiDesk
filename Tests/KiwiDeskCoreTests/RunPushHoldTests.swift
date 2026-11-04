import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A held resize along a run and a press at a weight's limit (#2709),
/// through the real writers on `RunPushCommandTests`' desk: a glide
/// step that would push ends the hold with no cue, and the press after
/// it pushes.
extension RunPushCommandTests {
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

    @Test("A press at the weight's limit in a zone that fits whole pushes")
    func spentWeightInAWholeZonePushes() throws {
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
        #expect(refusals.isEmpty)
        #expect(hidden(core, id) == [w(3)])
    }

    @Test("A hold in a run that hides stops on a length, mates at floors")
    func holdInAHidingRunStopsOnALength() throws {
        // Three windows in the stack zone: two fit, one waits.
        let (core, id) = makeSpace("stack", windows: 4, focus: 2)
        #expect(hidden(core, id) == [w(4)])
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.keys.holdGlide.isGliding = true
        core.keys.holdGlide.isApplyingGlideStep = true
        press(core, "y", 300)
        core.keys.holdGlide.isApplyingGlideStep = false
        #expect(hidden(core, id) == [w(4)])
        #expect(!core.keys.isGliding)
        #expect(refusals.isEmpty)
        #expect(core.state.workspaces[id]?.runSizes[w(2)] != nil)
        let frames = core.tiler.calculatedFrames(state: core.state)
        let mate = try #require(frames[w(3)])
        #expect(abs(mate.height - 300) < 1)
    }

    @Test("A held shrink at the weight's floor ends with no pill")
    func heldShrinkAtTheLimitIsSilent() throws {
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
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.keys.holdGlide.isGliding = true
        core.keys.holdGlide.isApplyingGlideStep = true
        press(core, "y", -5)
        core.keys.holdGlide.isApplyingGlideStep = false
        #expect(!core.keys.isGliding)
        #expect(refusals.isEmpty)
    }
}
