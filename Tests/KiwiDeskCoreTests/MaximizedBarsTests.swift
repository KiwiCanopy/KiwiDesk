import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

private let bounds = CGRect(x: 0, y: 25, width: 1600, height: 1000)
private let space = SpaceID("1")
private let display = DisplayID(1)
private let w1 = WindowID(1)
private let w2 = WindowID(2)

/// A bsp Space of two tiled windows on display 1, `w1` focused, the
/// Space Bar Always and the Pocket Always.
@MainActor
private func makeCore() -> KiwiCore {
    let core = makeTestCore()
    core.tiler.visibleBounds = { _ in bounds }
    for id in [w1, w2] {
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: id, pid: 900_011, appName: "A")
            )
        )
    }
    core.execute("set_mode", args: [.string("1"), .string("bsp")])
    core.state.workspaces.assign(space, to: display)
    core.state.workspaces.focus(w1, in: space)
    core.tiler.settings.spaceBarStyle.visibility = .always
    core.tiler.settings.kiwishelf.pocketVisibility = .always
    return core
}

/// A maximized window reads its bars Hidden, never a stand-down
/// (#3346): both bars and the Pocket read Hidden through the shelf's
/// door, the shortcut stays live, and Auto adds a hover band for
/// each bar not stored Hidden. Each case runs its control first.
@Suite("Maximized bars read Hidden or Auto (#3346)", .serialized)
@MainActor
struct MaximizedBarsTests {
    @Test("A maximize reads the bars Hidden and stands nothing down")
    func readsHidden() {
        let core = makeCore()
        // Control: unmaximized, the bar and the Pocket keep their Show.
        #expect(
            core.shelfSettings(on: display).spaceBarStyle.visibility
                == .always
        )
        #expect(core.pocketRests(on: display))
        core.execute("toggle_maximized")
        #expect(core.showsMaximized(on: display))
        let shown = core.shelfSettings(on: display)
        #expect(shown.spaceBarStyle.visibility == .hidden)
        #expect(!core.pocketRests(on: display))
        #expect(!core.shelfStandsDown(on: display))
        // An Always bar reads Hidden, so nothing keeps it shown.
        #expect(!shown.autoReadsAlways(.space, in: .bsp, on: nil))
        #expect(shown.revealActionLive(.space, in: .bsp))
    }

    /// The two refusals' absence is this case's claim: the fixture
    /// draws no target, and `FullscreenStandDownTests` ▸
    /// `maximizePocketRides` drives a reveal on a real screen.
    @Test("The shortcut is not refused as a stand-down or as Always")
    func revealIsNotRefused() {
        let core = makeCore()
        // Control: an Always bar refuses as Always.
        let always = core.execute("space_bar.toggle_reveal")
        #expect(always.error?.contains("set to always") == true)
        for value in ["auto", "hidden"] {
            core.execute(
                "kiwishelf.set_maximized_visibility",
                args: [.string(value)]
            )
            if core.state.workspaces[space].flatMap({
                core.state.maximizedWindow(of: $0)
            }) == nil {
                core.execute("toggle_maximized")
            }
            let response = core.execute("space_bar.toggle_reveal")
            #expect(response.error?.contains("set to always") != true)
            #expect(response.error?.contains("fills the screen") != true)
            // It reaches the reveal itself: a fixture screen has no
            // drawn target, so the bar has nothing to show here.
            #expect(
                response.isSuccess
                    || response.error?.contains("nothing to show") == true,
                "\(value)"
            )
        }
    }

    @Test("Auto bands each bar not stored Hidden; Hidden bands none")
    func hoverBars() {
        let core = makeCore()
        // Control: nothing is maximized, so nothing bands.
        #expect(core.maximizedHoverBars(on: display).isEmpty)
        core.execute("toggle_maximized")
        #expect(core.maximizedHoverBars(on: display) == [.space])
        core.tiler.settings.spaceBarStyle.visibility = .hidden
        #expect(core.maximizedHoverBars(on: display).isEmpty)
        core.tiler.settings.spaceBarStyle.visibility = .auto
        #expect(core.maximizedHoverBars(on: display) == [.space])
        core.execute(
            "kiwishelf.set_maximized_visibility",
            args: [.string("hidden")]
        )
        #expect(core.maximizedHoverBars(on: display).isEmpty)
        #expect(
            core.shelfSettings(on: display).spaceBarStyle.visibility
                == .hidden
        )
    }

    @Test("A maximizing Monocle bands its bars too")
    func monocleBands() {
        let core = makeCore()
        core.execute("set_mode", args: [.string("1"), .string("monocle")])
        // Control: Monocle without "Maximize windows" bands nothing.
        #expect(core.maximizedHoverBars(on: display).isEmpty)
        core.tiler.settings.monocle.maximizeWindows = true
        let bars = core.maximizedHoverBars(on: display)
        #expect(bars.contains(.space))
        let app = core.tiler.settings.appBarVisibility(in: .monocle)
        #expect(
            bars.contains(.app) == (app?.showsUnprompted == true)
        )
    }

    @Test("A tiling-off tick that hides the bars bands none")
    func tilingOffTickWins() {
        let core = makeCore()
        core.state.windows.setFloating(w1, true)
        core.execute("toggle_maximized")
        // Control: the maximized float bands the Space Bar.
        #expect(core.maximizedHoverBars(on: display) == [.space])
        core.execute("tiling.set_off_hides_bars", args: [.bool(true)])
        core.execute("set_tiling", args: [.bool(false)])
        #expect(core.maximizedHoverBars(on: display).isEmpty)
    }

    @Test("The leaf reads the stored bars, Hidden winning")
    func settingsAnswer() {
        var settings = TilingSettings()
        settings.spaceBarStyle.visibility = .always
        #expect(settings.kiwishelf.maximizedVisibility == .auto)
        #expect(settings.maximizedHoverBars(in: .bsp).contains(.space))
        settings.spaceBarStyle.visibility = .hidden
        #expect(!settings.maximizedHoverBars(in: .bsp).contains(.space))
        settings.spaceBarStyle.visibility = .auto
        settings.kiwishelf.maximizedVisibility = .hidden
        #expect(settings.maximizedHoverBars(in: .bsp).isEmpty)
        // Monocle's reading never comes out as `.auto`, so no edge
        // reserves its sliver under a maximize.
        settings.kiwishelf.maximizedVisibility = .auto
        settings.monocle.maximizeWindows = true
        #expect(settings.barVisibilities(in: .monocle).space == .hidden)
        #expect(settings.hidingEdges(in: .monocle, on: nil).isEmpty)
    }

    @Test("The Pocket rides under Auto unless it is stored Hidden")
    func pocketRides() {
        let core = makeCore()
        // Control: nothing is maximized, so nothing rides.
        #expect(!core.maximizedPocketRides(on: display))
        core.execute("toggle_maximized")
        #expect(core.maximizedPocketRides(on: display))
        core.tiler.settings.kiwishelf.pocketVisibility = .hidden
        #expect(!core.maximizedPocketRides(on: display))
        core.tiler.settings.kiwishelf.pocketVisibility = .auto
        core.execute(
            "kiwishelf.set_maximized_visibility",
            args: [.string("hidden")]
        )
        #expect(!core.maximizedPocketRides(on: display))
    }

    @Test("Something reveals unless every bar and the Pocket hide")
    func revealsAnything() {
        var settings = TilingSettings()
        settings.spaceBarStyle.visibility = .hidden
        settings.kiwishelf.pocketVisibility = .hidden
        for mode in LayoutMode.allCases {
            guard let path = TilingSettings.appBarPath(for: mode)
            else { continue }
            settings[keyPath: path].visibility = .hidden
        }
        #expect(!settings.maximizedRevealsAnything)
        var pocket = settings
        pocket.kiwishelf.pocketVisibility = .auto
        #expect(pocket.maximizedRevealsAnything)
        var bar = settings
        bar.spaceBarStyle.visibility = .always
        #expect(bar.maximizedRevealsAnything)
        for mode in LayoutMode.allCases {
            guard let path = TilingSettings.appBarPath(for: mode)
            else { continue }
            var app = settings
            app[keyPath: path].visibility = .auto
            #expect(app.maximizedRevealsAnything, "\(mode)")
        }
    }
}
