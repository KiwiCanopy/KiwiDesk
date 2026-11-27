import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `space_bar.set_edge` / `app_bar.set_edge` with the optional
/// screen (#1948), through `execute`: a screen is named as
/// `pin_space_to_display` names one, stored by its screen number
/// (#3647 ▸ lane 3c), a screen-less call clears every screen's own
/// edge, and a write collapses over the live profile's numbers and
/// the connected screens'. Also the looks, which keep the per-screen
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
        // Screen 2: left to right, the main screen is the right one
        // (#3647).
        #expect(edge(core, verb, .string("left"), .number(2)).isSuccess)
        #expect(
            edge(core, verb, .string("right"), .string("Left")).isSuccess
        )
        // A screen no setup holds has no number to store under.
        #expect(
            !edge(core, verb, .string("bottom"), .string(Self.away))
                .isSuccess
        )
        #expect(
            core.tiler.settings.spaceBarStyle.edgeOverride == [
                "2": .left,
                "1": .right,
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
        #expect(core.tiler.settings.spaceBarStyle.edgeOverride.count == 2)
    }

    @Test("The bar's own edge follows; a screen-less edge clears all")
    func followAndClear() {
        let saved = PositionalDisplays.mainIDOverride
        defer { PositionalDisplays.mainIDOverride = saved }
        let core = makeCore()
        let verb = "app_bar.set_edge"
        let left = JSONValue.string(Self.left.fingerprint)
        #expect(edge(core, verb, .string("bottom"), left).isSuccess)
        #expect(core.tiler.settings.appBarStyle.edgeOverride == ["1": .bottom])
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

    /// A number of the live profile no connected screen holds still
    /// follows the bar: collapsing would move it.
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
        #expect(core.liveScreenEdgeScope.screens.contains("3"))
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

    /// A set the live profile claims without an apply is judged at
    /// once (`ActiveProfile.refiled(_:)`); one of the same count adds
    /// no number, so every number agreeing still collapses.
    @Test("A claimed set of the same count adds no number")
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
        try core.claimMonitorSet(
            [Self.left.fingerprint, Self.away],
            for: "Desk"
        )
        #expect(core.liveScreenEdgeScope.screens == ["1", "2"])
        let verb = "space_bar.set_edge"
        for screen in ["Left", "Right"] {
            #expect(
                edge(core, verb, .string("left"), .string(screen))
                    .isSuccess
            )
        }
        #expect(core.tiler.settings.spaceBarStyle.edge == .left)
        #expect(core.tiler.settings.spaceBarStyle.edgeOverride.isEmpty)
    }

    /// Before the first display is published, outside a config
    /// load, a screen number is stored at once, while a fingerprint
    /// no setup holds has no number and refuses; `init.lua`'s own
    /// fingerprint calls wait for a screen (#3640, #3647,
    /// `BootDisplayAreaTests`).
    @Test("A screen is named before any display is published")
    func namesAScreenAtBoot() {
        let core = makeTestCore()
        #expect(core.state.workspaces.allDisplays.isEmpty)
        #expect(
            edge(core, "space_bar.set_edge", .string("left"), .number(1))
                .isSuccess
        )
        #expect(
            !edge(
                core,
                "app_bar.set_edge",
                .string("left"),
                .string(Self.left.fingerprint)
            ).isSuccess
        )
        #expect(core.tiler.settings.spaceBarStyle.edgeOverride == ["1": .left])
        #expect(core.tiler.settings.appBarStyle.edgeOverride.isEmpty)
        #expect(core.heldScreenCalls.isEmpty)
    }

    @Test("A look sets the bars' edges and keeps each screen's own")
    func lookKeepsScreenEdges() {
        var settings = TilingSettings()
        settings.spaceBarStyle.edgeOverride = ["1": .left, "2": .bottom]
        settings.appBarStyle.edgeOverride = ["1": .right]
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
            settings.spaceBarStyle.edgeOverride == ["1": .left, "2": .bottom]
        )
        #expect(settings.appBarStyle.edgeOverride == ["1": .right])
    }

    /// The layouts' refusal and the retired per-layout edge verbs
    /// read the one verb `AppBarStyle.layoutFixedKeys` names, so
    /// the per-screen key names no `set_edge_override` that does
    /// not exist.
    @Test("A layout refuses a screen edge naming app_bar.set_edge")
    func layoutRefusalNamesTheVerb() {
        let core = makeTestCore()
        let response = core.applyBarOverride(
            field: "edge_override",
            [.string("left")],
            into: .monocle
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
