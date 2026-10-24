import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A switch the Space Bar picked pays no Space cue: the chip the
/// user clicked already named the Space. The slide still plays.
extension FullscreenStandDownTests {
    @Test(
        "a Space Bar chip click shows no plate",
        .enabled(if: NSScreen.main != nil)
    )
    func chipClickNamesNothing() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, box, _) = try #require(
            makeSpaceCueCore(spaceBar: true)
        )
        core.spaceBars.onSelectSpace("2")
        #expect(core.state.workspaces.activeSpace == "2")
        #expect(box.cues.isEmpty)
        // The scope ends with the pick: the next switch is named.
        _ = core.execute("focus_space", args: [.string("1")])
        #expect(box.cues.map(\.space) == ["1"])
    }

    @Test(
        "a Space Bar list row shows no plate",
        .enabled(if: NSScreen.main != nil)
    )
    func rowPickNamesNothing() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, box, _) = try #require(
            makeSpaceCueCore(spaceBar: true)
        )
        let window = WindowID(9)
        core.state.apply(
            .windowCreated(ManagedWindow(id: window, pid: 1, appName: "A"))
        )
        core.state.workspaces.add(window, to: "2")
        core.shelves.peek.pick(window, "2")
        #expect(core.state.workspaces.activeSpace == "2")
        #expect(box.cues.isEmpty)
    }

    @Test(
        "a Space Bar chip click still slides",
        .enabled(if: NSScreen.main != nil)
    )
    func chipClickSlides() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, _, _) = try #require(
            makeSpaceCueCore(transition: .slide, spaceBar: true)
        )
        core.spaceSlide.reduceMotion = { false }
        core.spaceSlide.stackOrder = { [:] }
        core.spaceBars.onSelectSpace("2")
        #expect(core.spaceSlide.isPlaying)
        core.endSpaceSlide()
    }
}
