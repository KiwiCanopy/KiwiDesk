import Foundation
import Testing

@testable import KiwiDeskCore

/// A tiling-off Space whose tick hides the bars reads every bar
/// and the Pocket as Hidden (#3151): gone at rest, a shortcut still
/// shows one, and the shelf does not stand down as it does for a
/// window filling the screen. Each case runs its control first.
@Suite("Tiling off hides the bars as Hidden (#3151)", .serialized)
@MainActor
struct TilingOffBarsHiddenTests {
    private let space = SpaceID("1")
    private let display = DisplayID(7)

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-bars-hidden-\(UUID().uuidString)"
                )
        )
        core.state.workspaces.assign(space, to: display)
        core.state.workspaces.activate(space)
        core.execute("set_mode", args: [.string("1"), .string("scrolling")])
        return core
    }

    @Test("every bar and the Pocket read Hidden in every layout")
    func everyBarHidden() {
        var settings = TilingSettings()
        settings.spaceBarStyle.visibility = .always
        settings.kiwishelf.pocketVisibility = .auto
        let hidden = settings.hidingEveryBar()
        #expect(hidden.spaceBarStyle.visibility == .hidden)
        #expect(hidden.kiwishelf.pocketVisibility == .hidden)
        for mode in LayoutMode.allCases {
            let app = hidden.appBarVisibility(in: mode)
            #expect(app == nil || app == .hidden, "\(mode)")
        }
        #expect(!hidden.someBarShows)
        #expect(settings.someBarShows)
    }

    @Test("only a tiling-off Space with the tick reads them Hidden")
    func doorReadsTheTick() {
        let core = makeCore()
        core.tiler.settings.spaceBarStyle.visibility = .always
        core.execute("tiling.set_off_hides_bars", args: [.bool(true)])
        // Control: tiling on, the bar keeps its own Show.
        #expect(
            core.shelfSettings(on: display).spaceBarStyle.visibility
                == .always
        )
        core.execute("set_tiling", args: [.bool(false)])
        let shown = core.shelfSettings(on: display)
        #expect(shown.spaceBarStyle.visibility == .hidden)
        #expect(!shown.pocketRests(in: .scrolling))
        #expect(!core.pocketRests(on: display))
        #expect(!core.shelfStandsDown(on: display, covered: false))
        core.execute("tiling.set_off_hides_bars", args: [.bool(false)])
        #expect(
            core.shelfSettings(on: display).spaceBarStyle.visibility
                == .always
        )
    }

    @Test("the shortcut is not refused as a stand-down or as Always")
    func revealIsNotRefused() {
        let core = makeCore()
        core.tiler.settings.spaceBarStyle.visibility = .always
        // Control: an Always bar on a tiling Space refuses as Always.
        let always = core.execute("space_bar.toggle_reveal")
        #expect(always.error?.contains("set to always") == true)
        core.execute("tiling.set_off_hides_bars", args: [.bool(true)])
        core.execute("set_tiling", args: [.bool(false)])
        let response = core.execute("space_bar.toggle_reveal")
        #expect(response.error?.contains("set to always") != true)
        #expect(response.error?.contains("fills the screen") != true)
        // It reaches the reveal itself: a fixture screen has no
        // drawn target, so the bar has nothing to show here.
        #expect(
            response.isSuccess
                || response.error?.contains("nothing to show") == true
        )
    }
}
