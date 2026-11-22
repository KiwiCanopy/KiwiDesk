import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `space_bar.set_visibility` and `app_bar.set_visibility` take a
/// screen or area (#3517 ruling 30), resolved in ruling 16's order:
/// a number names a physical screen, an area key on a connected
/// screen goes through the one placement resolver — a gone area
/// falling back to the screen (ruling 22) — and a key for a screen
/// not connected is kept as given.
@Suite("Area bar visibility verbs (#3517)")
@MainActor
struct AreaBarVisibilityVerbTests {
    private let wide = Display(
        id: DisplayID(900_611),
        name: "Wide",
        frame: CGRect(x: 0, y: 0, width: 3440, height: 1440)
    )

    private func core(split: Bool) throws -> KiwiCore {
        let core = makeTestCore()
        core.honoursAreaSplits = true
        core.state.workspaces.upsertDisplay(wide)
        guard split else { return core }
        var settings = core.tiler.settings
        settings.displayAreas = [
            wide.fingerprint: try #require(
                ScreenSplit.whole(width: 3440, height: 1440)
                    .splitting(0, .sideBySide)
            )
        ]
        core.tiler.settings = settings
        return core
    }

    @Test func spaceBarTakesAnAreaAndCollapses() throws {
        let core = try core(split: true)
        let area = "Wide:3440x1440#1"
        let set = core.execute(
            "space_bar.set_visibility",
            args: [.string("hidden"), .string(area)]
        )
        #expect(set.isSuccess)
        #expect(
            core.tiler.settings.spaceBarStyle.visibilityOverride
                == [area: .hidden]
        )
        // The bar's own value stores nothing for the area.
        core.execute(
            "space_bar.set_visibility",
            args: [
                .string(core.tiler.settings.spaceBarStyle.visibility.rawValue),
                .string(area),
            ]
        )
        #expect(core.tiler.settings.spaceBarStyle.visibilityOverride.isEmpty)
        // A screen-less call sets every screen and clears theirs.
        core.execute(
            "space_bar.set_visibility",
            args: [.string("auto"), .string(area)]
        )
        core.execute("space_bar.set_visibility", args: [.string("always")])
        #expect(core.tiler.settings.spaceBarStyle.visibilityOverride.isEmpty)
        #expect(core.tiler.settings.spaceBarStyle.visibility == .always)
    }

    @Test func goneAreaFallsBackToItsScreen() throws {
        let core = try core(split: false)
        core.execute(
            "space_bar.set_visibility",
            args: [.string("hidden"), .string("Wide:3440x1440#4")]
        )
        #expect(
            core.tiler.settings.spaceBarStyle.visibilityOverride
                == [wide.fingerprint: .hidden]
        )
        // A screen that is not connected keeps the key it was given.
        core.execute(
            "space_bar.set_visibility",
            args: [.string("hidden"), .string("Away:1920x1080#2")]
        )
        #expect(
            core.tiler.settings.spaceBarStyle
                .visibilityOverride["Away:1920x1080#2"] == .hidden
        )
    }

    @Test func numberNamesThePhysicalScreen() throws {
        let core = try core(split: true)
        core.execute(
            "app_bar.set_visibility",
            args: [.string("hidden"), .number(1)]
        )
        #expect(
            core.tiler.settings.appBarStyle.visibilityOverride
                == [wide.fingerprint: .hidden]
        )
    }

    @Test func appBarNeedsAScreenAndLayoutsRefuseOne() throws {
        let core = try core(split: false)
        let bare = core.execute(
            "app_bar.set_visibility",
            args: [.string("hidden")]
        )
        #expect(bare.error?.contains("takes a screen") == true)
        let layout = core.execute(
            "monocle.set_app_bar_visibility",
            args: [.string("hidden"), .string(wide.fingerprint)]
        )
        #expect(layout.error?.contains("global") == true)
        #expect(core.tiler.settings.appBarStyle.visibilityOverride.isEmpty)
        let unknown = core.execute(
            "space_bar.set_visibility",
            args: [.string("hidden"), .string("nowhere")]
        )
        #expect(unknown.error?.contains("expected a screen") == true)
    }

    /// A layout's own App Bar Show clears every area's App Bar
    /// value, as its Settings row does (ruling 32); its other
    /// fields leave them.
    @Test func layoutShowClearsTheAreas() throws {
        let core = try core(split: true)
        let area = "Wide:3440x1440#1"
        core.execute(
            "app_bar.set_visibility",
            args: [.string("hidden"), .string(area)]
        )
        core.execute(
            "monocle.set_app_bar_title_cap",
            args: [.number(12)]
        )
        #expect(
            core.tiler.settings.appBarStyle.visibilityOverride
                == [area: .hidden]
        )
        let set = core.execute(
            "monocle.set_app_bar_visibility",
            args: [.string("auto")]
        )
        #expect(set.isSuccess)
        #expect(core.tiler.settings.monocle.appBar.visibility == .auto)
        #expect(core.tiler.settings.appBarStyle.visibilityOverride.isEmpty)
    }
}
