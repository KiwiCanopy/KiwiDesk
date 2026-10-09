import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `space_bar.set_edge` / `app_bar.set_edge` with the optional
/// screen (#1948), through `execute`: a screen is named as
/// `pin_space_to_display` names one, stored by fingerprint, a
/// screen-less call clears every screen's own edge, and a write
/// collapses over the live profile's monitor-set screens and the
/// connected ones. Also the looks, which keep the per-screen
/// edges, and the layouts, which refuse them naming the one verb
/// that writes them.
@Suite("Per-screen bar edge verbs (#1948)", .serialized)
@MainActor
struct ScreenEdgeVerbTests {
    private static let left = Display(
        id: DisplayID(7_001),
        name: "Left",
        frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
    )
    private static let right = Display(
        id: DisplayID(7_002),
        name: "Right",
        frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440)
    )
    private static let away = "Away:800x600"

    /// A core with both screens connected, `right` the main one.
    /// `makeTestCore` pins the main id for every suite, so a test
    /// restores the value it found.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore()
        PositionalDisplays.mainIDOverride = { Self.right.id }
        core.state.apply(.displaysChanged([Self.left, Self.right]))
        return core
    }

    private func edge(
        _ core: KiwiCore,
        _ verb: String,
        _ args: JSONValue...
    ) -> CommandResponse {
        core.execute(verb, args: args)
    }

    @Test("A screen is named by number, fingerprint or name")
    func screenArgument() {
        let saved = PositionalDisplays.mainIDOverride
        defer { PositionalDisplays.mainIDOverride = saved }
        let core = makeCore()
        let verb = "space_bar.set_edge"
        #expect(edge(core, verb, .string("left"), .number(1)).isSuccess)
        #expect(
            edge(core, verb, .string("right"), .string("Left")).isSuccess
        )
        // A screen that is not connected is stored as given.
        #expect(
            edge(core, verb, .string("bottom"), .string(Self.away))
                .isSuccess
        )
        #expect(
            core.tiler.settings.spaceBarStyle.edgeOverride == [
                Self.right.fingerprint: .left,
                Self.left.fingerprint: .right,
                Self.away: .bottom,
            ]
        )
        #expect(core.tiler.settings.spaceBarStyle.edge == .top)
        for screen in ["Nope", "X:-5x0", "X:0x10", ":10x10"] {
            let refused = edge(core, verb, .string("left"), .string(screen))
            #expect(!refused.isSuccess, Comment(rawValue: screen))
            #expect(refused.error == KiwiCore.unknownScreen)
        }
        // A bad edge answers as one, whatever the screen.
        let badEdge = edge(core, verb, .string("diagonal"), .string("Nope"))
        #expect(badEdge.error?.hasPrefix("expected top") == true)
        #expect(core.tiler.settings.spaceBarStyle.edgeOverride.count == 3)
    }

    @Test("The bar's own edge follows; a screen-less edge clears all")
    func followAndClear() {
        let saved = PositionalDisplays.mainIDOverride
        defer { PositionalDisplays.mainIDOverride = saved }
        let core = makeCore()
        let verb = "app_bar.set_edge"
        let left = JSONValue.string(Self.left.fingerprint)
        #expect(edge(core, verb, .string("bottom"), left).isSuccess)
        #expect(
            core.tiler.settings.appBarStyle.edgeOverride
                == [Self.left.fingerprint: .bottom]
        )
        #expect(edge(core, verb, .string("top"), left).isSuccess)
        #expect(core.tiler.settings.appBarStyle.edgeOverride.isEmpty)
        #expect(edge(core, verb, .string("bottom"), left).isSuccess)
        #expect(edge(core, verb, .string("right")).isSuccess)
        #expect(core.tiler.settings.appBarStyle.edge == .right)
        #expect(core.tiler.settings.appBarStyle.edgeOverride.isEmpty)
    }

    @Test("Every connected screen agreeing collapses into the bar's edge")
    func collapses() {
        let saved = PositionalDisplays.mainIDOverride
        defer { PositionalDisplays.mainIDOverride = saved }
        let core = makeCore()
        let verb = "space_bar.set_edge"
        #expect(
            edge(core, verb, .string("left"), .string("Left")).isSuccess
        )
        #expect(core.tiler.settings.spaceBarStyle.edge == .top)
        #expect(
            edge(core, verb, .string("left"), .string("Right")).isSuccess
        )
        #expect(core.tiler.settings.spaceBarStyle.edge == .left)
        #expect(core.tiler.settings.spaceBarStyle.edgeOverride.isEmpty)
    }

    /// A screen of the live profile's monitor set that is not
    /// connected still follows the bar: collapsing would move it.
    @Test("A monitor-set screen that is away blocks the collapse")
    func awayScreenBlocksCollapse() throws {
        let saved = PositionalDisplays.mainIDOverride
        defer { PositionalDisplays.mainIDOverride = saved }
        let core = makeCore()
        try core.profiles.save(
            Profile(
                name: "Desk",
                monitorSets: [
                    MonitorSet(
                        monitors: [
                            Self.left.fingerprint,
                            Self.right.fingerprint,
                            Self.away,
                        ]
                    )
                ],
                spaceModes: [:],
                settings: TilingSettings()
            )
        )
        #expect(core.liveScreenEdgeScope.screens.contains(Self.away))
        let verb = "space_bar.set_edge"
        for screen in ["Left", "Right"] {
            #expect(
                edge(core, verb, .string("left"), .string(screen))
                    .isSuccess
            )
        }
        #expect(core.tiler.settings.spaceBarStyle.edge == .top)
        #expect(core.tiler.settings.spaceBarStyle.edgeOverride.count == 2)
    }

    /// A set the live profile claims without an apply joins the
    /// judged screens at once: the profile's file write re-files
    /// its sets (`ActiveProfile.refiled(_:)`).
    @Test("A claimed set's away screen blocks the collapse")
    func claimedSetBlocksCollapse() throws {
        let saved = PositionalDisplays.mainIDOverride
        defer { PositionalDisplays.mainIDOverride = saved }
        let core = makeCore()
        let connected = [Self.left.fingerprint, Self.right.fingerprint]
        try core.profiles.save(
            Profile(
                name: "Desk",
                monitorSets: [MonitorSet(monitors: connected)],
                spaceModes: [:],
                settings: TilingSettings()
            )
        )
        #expect(!core.liveScreenEdgeScope.screens.contains(Self.away))
        try core.claimMonitorSet(
            [Self.left.fingerprint, Self.away],
            for: "Desk"
        )
        #expect(core.liveScreenEdgeScope.screens.contains(Self.away))
        let verb = "space_bar.set_edge"
        for screen in ["Left", "Right"] {
            #expect(
                edge(core, verb, .string("left"), .string(screen))
                    .isSuccess
            )
        }
        #expect(core.tiler.settings.spaceBarStyle.edge == .top)
        #expect(core.tiler.settings.spaceBarStyle.edgeOverride.count == 2)
    }

    /// Before the first display is published — `init.lua` at
    /// boot — the screen list names the screens.
    @Test(
        "A screen is named before any display is published",
        .enabled(if: NSScreen.main != nil)
    )
    func namesAScreenAtBoot() throws {
        let screen = try #require(NSScreen.screens.first)
        let display = try #require(screen.kiwiDisplay)
        let core = makeTestCore()
        #expect(core.state.workspaces.allDisplays.isEmpty)
        let saved = ScreenList.override
        defer { ScreenList.override = saved }
        ScreenList.override = { [screen] }
        let main = PositionalDisplays.mainIDOverride
        defer { PositionalDisplays.mainIDOverride = main }
        PositionalDisplays.mainIDOverride = { display.id }
        #expect(
            edge(core, "space_bar.set_edge", .string("left"), .number(1))
                .isSuccess
        )
        #expect(
            core.tiler.settings.spaceBarStyle.edge(on: display.fingerprint)
                == .left
        )
        ScreenList.override = { [] }
        #expect(
            !edge(core, "app_bar.set_edge", .string("left"), .number(1))
                .isSuccess
        )
    }

    @Test("A look sets the bars' edges and keeps each screen's own")
    func lookKeepsScreenEdges() {
        var settings = TilingSettings()
        settings.spaceBarStyle.edgeOverride = [
            Self.left.fingerprint: .left,
            Self.right.fingerprint: .bottom,
        ]
        settings.appBarStyle.edgeOverride = [Self.left.fingerprint: .right]
        for bar in ["space_bar", "app_bar"] {
            ShelfLook.apply(
                path: "\(bar).edge",
                value: .string("bottom"),
                to: &settings
            )
        }
        #expect(settings.spaceBarStyle.edge == .bottom)
        #expect(settings.appBarStyle.edge == .bottom)
        // Untouched, the entry the look's edge now equals too.
        #expect(
            settings.spaceBarStyle.edgeOverride == [
                Self.left.fingerprint: .left,
                Self.right.fingerprint: .bottom,
            ]
        )
        #expect(
            settings.appBarStyle.edgeOverride
                == [Self.left.fingerprint: .right]
        )
    }

    /// The layouts' refusal and the retired per-layout edge verbs
    /// read the one verb `AppBarStyle.layoutFixedKeys` names, so
    /// the per-screen key names no `set_edge_override` that does
    /// not exist.
    @Test("A layout refuses a screen edge naming app_bar.set_edge")
    func layoutRefusalNamesTheVerb() {
        let core = makeTestCore()
        var bar = LayoutAppBar()
        let response = core.applyBarOverride(
            field: "edge_override",
            [.string("left")],
            into: &bar
        )
        #expect(!response.isSuccess)
        #expect(
            response.error
                == "the App Bar's edge_override is global: app_bar.set_edge"
        )
        #expect(
            AppBarStyle.layoutFixedKeys[.edgeOverride] == "app_bar.set_edge"
        )
        for layout in ["monocle", "scroll"] {
            #expect(
                APIReference.retired["\(layout).set_app_bar_edge_override"]
                    == nil
            )
        }
        #expect(
            !APIReference.retired.values.contains(
                .some("app_bar.set_edge_override")
            )
        )
    }
}
