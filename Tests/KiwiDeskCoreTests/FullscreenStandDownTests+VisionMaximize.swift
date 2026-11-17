import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiVision's plate stands down where the screen is covered — a
/// native fullscreen Space or a presentation — and never for a
/// Maximize, which reads the bars Hidden (#3061, #3346). An
/// extension of this suite, not a second one: every case holds the
/// process-global `currentSpaceIsUserOverride` (see the suite's
/// header).
extension FullscreenStandDownTests {
    /// A core with two tiled windows on the primary screen's Space,
    /// the first focused, its Space Bar always shown. Nil where the
    /// host has no screen.
    private func makeMaximizeCore(isUser: Bool) -> (KiwiCore, DisplayID)? {
        guard let screen = NSScreen.screens.first,
            let display = screen.kiwiDisplay
        else { return nil }
        NativeSpaces.currentSpaceIsUserOverride = { _ in isUser }
        let core = makeCore()
        core.tiler.visibleBounds = { _ in screen.frame }
        core.frontStack = { [] }
        core.state.apply(.displaysChanged([display]))
        for raw in [UInt32(1), 2] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: pid_t(900_000 + raw),
                        appName: "App\(raw)"
                    )
                )
            )
        }
        core.resolveSpaceDisplays(mainID: display.id)
        guard let space = core.state.workspaces.space(of: WindowID(1))
        else { return nil }
        core.state.workspaces.setMode(space, .bsp)
        core.state.workspaces.focus(WindowID(1), in: space)
        core.tiler.settings.spaceBarStyle.visibility = .always
        return (core, display.id)
    }

    @Test("a Maximize hides the bars and keeps the plate")
    func maximizeKeepsThePlate() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, display) = try #require(
            makeMaximizeCore(isUser: true)
        )
        core.updateBars()
        #expect(!core.spaceBars.shownStrips.isEmpty)
        #expect(core.vision.standDown.isEmpty)

        #expect(core.execute("toggle_maximized").isSuccess)
        #expect(core.showsMaximized(on: display))
        core.updateBars()
        #expect(core.spaceBars.shownStrips.isEmpty)
        #expect(!core.vision.standDown.contains(display))
    }

    /// The control: a covered screen still stands the plate down,
    /// so the case above cannot pass on a plate that never does.
    @Test("a fullscreen Space stands the plate down")
    func fullscreenStandsThePlateDown() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, display) = try #require(
            makeMaximizeCore(isUser: false)
        )
        core.updateBars()
        #expect(core.spaceBars.shownStrips.isEmpty)
        #expect(core.vision.standDown.contains(display))
    }

    /// A directional Maximize hides the bars only where its fill
    /// reaches their strip (#3062): a centred Width fill clears a
    /// top or bottom bar, a Height fill reaches it.
    @Test("a Width fill keeps the bars; a Height fill hides them")
    func directionalReachIsWired() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, display) = try #require(
            makeMaximizeCore(isUser: true)
        )
        core.execute(
            "toggle_maximized",
            args: [.string("width"), .number(0.5)]
        )
        #expect(core.showsMaximized(on: display) == false)
        core.updateBars()
        #expect(!core.spaceBars.shownStrips.isEmpty)
        core.execute("toggle_maximized", args: [.string("height")])
        #expect(core.showsMaximized(on: display))
        core.updateBars()
        #expect(core.spaceBars.shownStrips.isEmpty)
        #expect(!core.vision.standDown.contains(display))
        // A bar drawn over the windows still has a strip to cover.
        core.tiler.settings.spaceBarStyle.reserve = false
        #expect(core.showsMaximized(on: display))
    }

    /// Over a maximized window the Space Bar is filed with an
    /// approach under Auto and without one under Hidden, and no
    /// stand-down retires its target (#3346, #3349).
    @Test("a Maximize files an approach under Auto, none under Hidden")
    func maximizeFilesTheBand() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, display) = try #require(
            makeMaximizeCore(isUser: true)
        )
        let band = { () -> CGRect?? in
            core.shelves.reveal.targets.first {
                $0.key.shelf.display == display && $0.key.bar == .space
            }.map(\.value.approach)
        }
        // A margin, which the approach must not count twice.
        core.tiler.settings.kiwishelf.outerMargin = 6
        // Control: an Always bar is no hiding bar, so no target.
        core.updateBars()
        #expect(band() == nil)
        #expect(core.execute("toggle_maximized").isSuccess)
        core.updateBars()
        let over = try #require(band() ?? nil)
        // Over the window it reaches in only to the handle's hover
        // band (#3349, #3360), never the 24 pt an Auto bar's approach
        // takes.
        #expect(
            over.height
                == ShelfReveal.overshoot + ShelfHandleSpec.hoverDepth
        )
        core.execute(
            "kiwishelf.set_maximized_visibility",
            args: [.string("hidden")]
        )
        core.updateBars()
        let hidden = try #require(band())
        #expect(hidden == nil)
    }

    /// Over a maximized window the Pocket rests nowhere, and a bar
    /// revealed on its edge comes in alone (#3432, retiring #3346 ▸
    /// 8).
    @Test("a Maximize's revealed bar comes in without the Pocket")
    func maximizeRevealLeavesThePocket() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, display) = try #require(
            makeMaximizeCore(isUser: true)
        )
        core.tiler.settings.kiwishelf.pocketEdge =
            core.tiler.settings.spaceBarStyle.edge
        core.tiler.settings.kiwishelf.pocketVisibility = .always
        #expect(core.execute("toggle_maximized").isSuccess)
        core.updateBars()
        #expect(!core.pocketStands(on: display))
        let bar = ShelfRevealer.Key(
            shelf: ShelfManager.Key(
                display: display,
                edge: core.tiler.settings.spaceBarStyle.edge
            ),
            bar: .space
        )
        #expect(core.execute("space_bar.toggle_reveal").isSuccess)
        core.updateBars()
        // Control: the reveal took, so the bar is drawn.
        #expect(core.shelves.reveal.reveal(of: bar).isShown)
        #expect(core.pocketPlate.slots[display] == nil)
        #expect(!core.pocketStands(on: display))
    }

    /// The overflow marks sit on windows a maximize covers, so they
    /// stand down on its screen though the shelf does not (#3346).
    @Test("a Maximize stands the overflow marks down alone")
    func maximizeStandsTheMarksDown() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, display) = try #require(
            makeMaximizeCore(isUser: true)
        )
        // Control: unmaximized, nothing stands down.
        core.updateBars()
        #expect(!core.overflowMarks.standingDown.contains(display))
        #expect(core.execute("toggle_maximized").isSuccess)
        core.updateBars()
        #expect(core.overflowMarks.standingDown.contains(display))
        #expect(!core.shelfStandsDown(on: display))
    }
}
