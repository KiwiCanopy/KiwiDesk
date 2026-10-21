import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The Space cue (#2143, #2524): an explicit switch pays a cue
/// naming the Space and its layout on the screen that switched,
/// while the drawn transition is Show the Space — a Space Bar or
/// not — and stands down where the shelf stands down (#1787).
/// An extension of this suite, not a second one: every case holds
/// the process-global `currentSpaceIsUserOverride`.
extension FullscreenStandDownTests {
    private final class SpaceCueBox { var cues: [SpaceSwitchCue] = [] }

    /// Two Spaces on the primary screen, "1" shown, the Space Bar
    /// on or off. Nil where the host has no screen.
    private func makeSpaceCueCore(
        transition: SpaceTransition = .show,
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
        core.frontStack = { [] }
        core.setAppWide(persisting: false) {
            $0.spaceTransition = transition
        }
        var settings = core.tiler.settings
        settings.spaceBarStyle.visibility = spaceBar ? .always : .hidden
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
        "with the transition on None, a switch shows no plate",
        .enabled(if: NSScreen.main != nil)
    )
    func toggleDecidesTheCue() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, box, _) = try #require(makeSpaceCueCore(transition: .none))
        _ = core.execute("focus_space", args: [.string("2")])
        #expect(box.cues.isEmpty)
    }

    /// Slide under Reduce Motion shows the Space instead (#2524),
    /// and a slide that plays is the cue itself, so no plate.
    @Test(
        "Slide shows the plate only under Reduce Motion",
        .enabled(if: NSScreen.main != nil)
    )
    func slideFallsBackUnderReduceMotion() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        for reduced in [true, false] {
            let (core, box, display) = try #require(
                makeSpaceCueCore(transition: .slide)
            )
            core.spaceSlide.reduceMotion = { reduced }
            core.spaceSlide.stackOrder = { [:] }
            _ = core.execute("focus_space", args: [.string("2")])
            #expect(
                box.cues
                    == (reduced
                        ? [
                            SpaceSwitchCue(
                                display: display,
                                space: "2",
                                mode: .grid
                            )
                        ] : [])
            )
            core.endSpaceSlide()
        }
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
        "a screen drawing a Space Bar shows the plate too",
        .enabled(if: NSScreen.main != nil)
    )
    func spaceBarKeepsTheCue() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, box, display) = try #require(
            makeSpaceCueCore(spaceBar: true)
        )
        #expect(core.spaceBars.shownDisplays.contains(display))
        _ = core.execute("focus_space", args: [.string("2")])
        #expect(
            box.cues
                == [SpaceSwitchCue(display: display, space: "2", mode: .grid)]
        )
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

    /// The slide stands down there too (#2524): instant, with no
    /// plate of either kind.
    @Test(
        "a full-screen Space plays no slide",
        .enabled(if: NSScreen.main != nil)
    )
    func fullScreenKeepsTheSlideAway() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, box, _) = try #require(
            makeSpaceCueCore(transition: .slide, isUser: false)
        )
        core.spaceSlide.reduceMotion = { false }
        _ = core.execute("focus_space", args: [.string("2")])
        #expect(!core.spaceSlide.isPlaying)
        #expect(box.cues.isEmpty)
    }

    /// A display follow lands on a Space its screen already shows,
    /// so nothing needs naming: it passes no screen to the switch.
    @Test(
        "a display follow names nothing",
        .enabled(if: NSScreen.main != nil)
    )
    func displayFollowNamesNothing() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, box, _) = try #require(makeSpaceCueCore())
        core.applyFocusedSpaceSwitch(to: "2")
        #expect(core.state.workspaces.activeSpace == "2")
        #expect(box.cues.isEmpty)
    }

    /// A Space no declaration names takes its screen ahead of the
    /// cue's read (#1994), so a first visit, a move-and-follow and
    /// a launch follow into one name it too.
    @Test(
        "an undeclared Space is named on its first visit",
        .enabled(if: NSScreen.main != nil)
    )
    func firstVisitIsNamed() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, box, display) = try #require(makeSpaceCueCore())
        _ = core.execute("focus_space", args: [.string("6")])
        #expect(core.state.workspaces.display(of: "6") == display)
        #expect(box.cues.map(\.space) == ["6"])
    }

    /// The filing places the Space before the follow reads its
    /// screen, so this holds whichever of the two placements runs;
    /// `followSwitch`'s own is `launchFollowIsNamed`'s.
    @Test(
        "a move-and-follow into an undeclared Space names it",
        .enabled(if: NSScreen.main != nil)
    )
    func followIsNamed() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, box, display) = try #require(makeSpaceCueCore())
        let window = WindowID(9)
        core.state.apply(
            .windowCreated(ManagedWindow(id: window, pid: 1, appName: "A"))
        )
        core.state.workspaces.add(window, to: "1")
        _ = core.execute(
            "move_to_space_and_follow",
            args: [.string("6"), .number(9)]
        )
        #expect(core.state.workspaces.display(of: "6") == display)
        #expect(box.cues.map(\.space) == ["6"])
    }

    /// The create fold files a launch's window into its rule's
    /// Space and places nothing; the follow places it first.
    @Test(
        "a launch follow into an undeclared Space names it",
        .enabled(if: NSScreen.main != nil)
    )
    func launchFollowIsNamed() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, box, display) = try #require(makeSpaceCueCore())
        let window = WindowID(9)
        core.state.apply(
            .windowCreated(ManagedWindow(id: window, pid: 1, appName: "A"))
        )
        core.state.workspaces.add(window, to: "6")
        #expect(core.state.workspaces.display(of: "6") == nil)
        core.followSwitch(to: "6", focusing: window)
        #expect(core.state.workspaces.display(of: "6") == display)
        #expect(box.cues.map(\.space) == ["6"])
    }
}
