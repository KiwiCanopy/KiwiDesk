import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The Space cue (#2143, #2228): an explicit switch pays a cue
/// naming the Space and its layout on the screen that switched,
/// while `space.cue` is on, and stands down where that screen draws
/// a Space Bar or the shelf stands down (#1787).
/// An extension of this suite, not a second one: every case holds
/// the process-global `currentSpaceIsUserOverride`.
extension FullscreenStandDownTests {
    private final class SpaceCueBox { var cues: [SpaceSwitchCue] = [] }

    /// Two Spaces on the primary screen, "1" shown, the Space Bar
    /// on or off. Nil where the host has no screen.
    private func makeSpaceCueCore(
        cue: Bool = true,
        spaceBar: Bool = false,
        isUser: Bool = true
    ) -> (KiwiCore, SpaceCueBox, DisplayID)? {
        guard let screen = NSScreen.screens.first,
            let display = screen.kiwiDisplay
        else { return nil }
        NativeSpaces.currentSpaceIsUserOverride = { _ in isUser }
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        for id in ["1", "2"] {
            core.state.workspaces.ensureSpace(SpaceID(id))
            core.state.workspaces.assign(SpaceID(id), to: display.id)
        }
        core.state.workspaces.setMode("2", .grid)
        core.state.workspaces.activate("1")
        core.frontWindowFrames = { [] }
        core.setAppWide(persisting: false) { $0.spaceCue = cue }
        var settings = core.tiler.settings
        settings.spaceBarStyle.enabled = spaceBar
        core.tiler.settings = settings
        core.updateBars()
        let box = SpaceCueBox()
        core.onSpaceCue = { box.cues.append($0) }
        return (core, box, display.id)
    }

    @Test(
        "a switch names the Space and its layout",
        .enabled(if: NSScreen.main != nil)
    )
    func switchPaysTheSpaceCue() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, box, display) = try #require(
            makeSpaceCueCore()
        )
        _ = core.execute("focus_space", args: [.string("2")])
        #expect(
            box.cues
                == [SpaceSwitchCue(display: display, space: "2", mode: .grid)]
        )
    }

    @Test(
        "with space.cue off, a switch shows no plate",
        .enabled(if: NSScreen.main != nil)
    )
    func toggleDecidesTheCue() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, box, _) = try #require(makeSpaceCueCore(cue: false))
        _ = core.execute("focus_space", args: [.string("2")])
        #expect(box.cues.isEmpty)
    }

    /// A follow pays it too: `followSwitch` hands the switch the
    /// same intent an explicit switch does.
    @Test(
        "a move-and-follow names the Space it lands on",
        .enabled(if: NSScreen.main != nil)
    )
    func followPaysTheSpaceCue() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, box, display) = try #require(
            makeSpaceCueCore()
        )
        let window = WindowID(9)
        core.state.apply(
            .windowCreated(ManagedWindow(id: window, pid: 1, appName: "A"))
        )
        core.state.workspaces.withSpace("1") { $0.focused = window }
        core.followSwitch(to: "2", focusing: window)
        #expect(
            box.cues
                == [SpaceSwitchCue(display: display, space: "2", mode: .grid)]
        )
    }

    @Test(
        "a screen drawing a Space Bar shows no plate",
        .enabled(if: NSScreen.main != nil)
    )
    func spaceBarKeepsTheCueAway() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, box, display) = try #require(
            makeSpaceCueCore(spaceBar: true)
        )
        #expect(core.spaceBars.shownDisplays.contains(display))
        _ = core.execute("focus_space", args: [.string("2")])
        #expect(box.cues.isEmpty)
    }

    @Test(
        "a full-screen Space shows no plate",
        .enabled(if: NSScreen.main != nil)
    )
    func fullScreenKeepsTheSpaceCueAway() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, box, _) = try #require(
            makeSpaceCueCore(isUser: false)
        )
        _ = core.execute("focus_space", args: [.string("2")])
        #expect(box.cues.isEmpty)
    }
}
