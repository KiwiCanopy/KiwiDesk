import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A switch the Space Bar picked pays no Space cue (#2591): the
/// chip the user clicked already named the Space. The slide still
/// plays, and a pick from any other door keeps the plate.
extension FullscreenStandDownTests {
    /// The cue fixture with one window filed in Space "2".
    private func coreWithWindowOn2(
        transition: SpaceTransition = .show
    ) -> (KiwiCore, SpaceCueBox, WindowID)? {
        guard
            let (core, box, _) = makeSpaceCueCore(
                transition: transition,
                spaceBar: true
            )
        else { return nil }
        let window = WindowID(9)
        core.state.apply(
            .windowCreated(ManagedWindow(id: window, pid: 1, appName: "A"))
        )
        core.state.workspaces.add(window, to: "2")
        return (core, box, window)
    }

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
        "a Space Bar glyph click shows no plate",
        .enabled(if: NSScreen.main != nil)
    )
    func glyphPickNamesNothing() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, box, window) = try #require(coreWithWindowOn2())
        core.spaceBars.glyphActions.pick(
            SpaceBarGlyphPick(
                space: "2",
                windows: [window],
                kind: .glyph,
                anchor: NSView()
            )
        )
        #expect(core.state.workspaces.activeSpace == "2")
        #expect(box.cues.isEmpty)
    }

    /// The window switcher picks the same row unscoped, so the
    /// control proves the row's switch pays a cue at all.
    @Test(
        "a Space Bar list row shows no plate; the switcher's does",
        .enabled(if: NSScreen.main != nil)
    )
    func rowPickNamesNothing() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, box, window) = try #require(coreWithWindowOn2())
        core.shelves.peek.pick(window, "2")
        #expect(core.state.workspaces.activeSpace == "2")
        #expect(box.cues.isEmpty)

        let (control, controlBox, controlWindow) = try #require(
            coreWithWindowOn2()
        )
        control.pickBarRow(controlWindow, on: "2")
        #expect(controlBox.cues.map(\.space) == ["2"])
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

    /// Slide under Reduce Motion draws Show the Space, so a pick
    /// the bar made there draws neither.
    @Test(
        "a Space Bar chip click under Reduce Motion draws nothing",
        .enabled(if: NSScreen.main != nil)
    )
    func chipClickUnderReduceMotion() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, box, _) = try #require(
            makeSpaceCueCore(transition: .slide, spaceBar: true)
        )
        core.spaceSlide.reduceMotion = { true }
        core.spaceBars.onSelectSpace("2")
        #expect(!core.spaceSlide.isPlaying)
        #expect(box.cues.isEmpty)
    }
}
