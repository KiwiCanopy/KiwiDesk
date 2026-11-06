import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The plate reads the pick for the switch's input (#2971). An
/// extension of this suite, not a second one: every case holds the
/// process-global `currentSpaceIsUserOverride`.
extension FullscreenStandDownTests {
    @Test(
        "the plate follows the scroll step's own pick",
        .enabled(if: NSScreen.main != nil)
    )
    func scrollCueFollowsItsPick() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, box, display) = try #require(
            makeSpaceCueCore(transition: .none)
        )
        core.setAppWide(persisting: false) {
            $0.spaceScrollTransition = .show
        }
        core.stepSpace(on: display, by: 1, warp: false, scrolled: true)
        #expect(box.cues.map(\.space) == ["2"])
        core.stepSpace(on: display, by: -1, warp: false, scrolled: false)
        #expect(box.cues.map(\.space) == ["2"])
    }

    /// A Slide on the scroll step under Reduce Motion draws the plate
    /// even with every other switch on None; `makeTestCore` pins the
    /// read on.
    @Test(
        "Reduce Motion shows the Space on the scroll step",
        .enabled(if: NSScreen.main != nil)
    )
    func reduceMotionWinsOnTheScrollStep() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, box, display) = try #require(
            makeSpaceCueCore(transition: .none)
        )
        #expect(core.appWide.spaceScrollTransition == .slide)
        core.stepSpace(on: display, by: 1, warp: false, scrolled: true)
        #expect(box.cues.map(\.space) == ["2"])
    }
}
