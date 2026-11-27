import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `space_bar.set_visibility` and a layout's
/// `set_app_bar_visibility` take a screen or area (#3517 ruling 30,
/// #3618), resolved in ruling 16's order:
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
        core.state.workspaces.upsertDisplay(wide)
        guard split else { return core }
        var settings = core.tiler.settings
        settings.displayAreas.store(
            ScreenSplit.whole(width: 3440, height: 1440)
                .splitting(0, .sideBySide),
            on: wide.fingerprint,
            order: core.liveScreenOrder
        )
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
                == ["1#1": .hidden]
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
                == ["1": .hidden]
        )
        // A screen no setup holds has no number to store under.
        let away = core.execute(
            "space_bar.set_visibility",
            args: [.string("hidden"), .string("Away:1920x1080#2")]
        )
        #expect(!away.isSuccess)
        #expect(
            core.tiler.settings.spaceBarStyle.visibilityOverride.count == 1
        )
    }

    @Test func numberNamesThePhysicalScreen() throws {
        let core = try core(split: true)
        core.execute(
            "monocle.set_app_bar_visibility",
            args: [.string("hidden"), .number(1)]
        )
        // A physical screen writes each of its areas, in that
        // layout alone (#3618).
        #expect(
            core.tiler.settings.scrolling.appBar.visibilityOverride
                .isEmpty
        )
        #expect(
            core.tiler.settings.monocle.appBar.visibilityOverride == [
                "1": .hidden, "1#1": .hidden,
            ]
        )
    }

    /// The App Bar's per-area Show is a layout's (#3618): the global
    /// verb is gone, and a layout's verb takes a screen.
    @Test func layoutVerbTakesTheScreen() throws {
        let core = try core(split: false)
        let global = core.execute(
            "app_bar.set_visibility",
            args: [.string("hidden"), .string(wide.fingerprint)]
        )
        // The style's guard refuses it; a parse alone would answer
        // `.ok` and write nothing.
        #expect(global.error?.contains("unknown bar setting") == true)
        #expect(
            core.tiler.settings.appBarHosts.map(\.visibilityOverride)
                .allSatisfy { $0.isEmpty }
        )
        // Every layout-only field is the layouts' alone.
        let styleKeys = Set(
            AppBarStyle.CodingKeys.allCases.map(\.stringValue)
        )
        for key in LayoutAppBar.Key.allCases
        where !styleKeys.contains(key.stringValue) {
            let field = BarStyleKeys.setterField(of: key.stringValue)
            let answer = core.execute(
                "app_bar.set_\(field)",
                args: [.string("hidden"), .string(wide.fingerprint)]
            )
            #expect(
                answer.error?.contains("unknown bar setting") == true,
                Comment(rawValue: field)
            )
        }
        let layout = core.execute(
            "scroll.set_app_bar_visibility",
            args: [.string("hidden"), .string(wide.fingerprint)]
        )
        #expect(layout.isSuccess)
        #expect(
            core.tiler.settings.scrolling.appBar.visibilityOverride
                == ["1": .hidden]
        )
        #expect(core.tiler.settings.scrolling.appBar.visibility == .always)
        #expect(
            core.tiler.settings.monocle.appBar.visibilityOverride
                .isEmpty
        )
        let unknown = core.execute(
            "space_bar.set_visibility",
            args: [.string("hidden"), .string("nowhere")]
        )
        #expect(unknown.error?.contains("expected a screen") == true)
    }

    /// A layout's own App Bar Show clears that layout's area
    /// values, as its Settings row does (ruling 32, narrowed by
    /// #3618); its other fields and other layouts leave them.
    @Test func layoutShowClearsTheAreas() throws {
        let core = try core(split: true)
        let area = "Wide:3440x1440#1"
        for layout in ["monocle", "scroll"] {
            core.execute(
                "\(layout).set_app_bar_visibility",
                args: [.string("hidden"), .string(area)]
            )
        }
        core.execute(
            "monocle.set_app_bar_title_cap",
            args: [.number(12)]
        )
        #expect(
            core.tiler.settings.monocle.appBar.visibilityOverride
                == ["1#1": .hidden]
        )
        let set = core.execute(
            "monocle.set_app_bar_visibility",
            args: [.string("auto")]
        )
        #expect(set.isSuccess)
        #expect(core.tiler.settings.monocle.appBar.visibility == .auto)
        #expect(
            core.tiler.settings.monocle.appBar.visibilityOverride
                .isEmpty
        )
        #expect(
            core.tiler.settings.scrolling.appBar.visibilityOverride
                == ["1#1": .hidden]
        )
    }
}
