import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `space_bar.set_edge` / `app_bar.set_edge` with the optional
/// screen (#1948), through `execute`: a screen is named as
/// `pin_space_to_display` names one, stored by fingerprint, and a
/// screen-less call clears every screen's own edge. Also the
/// looks, which leave the per-screen edges alone, and the layouts,
/// which refuse them naming the one verb that writes them.
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

    /// A core with both screens connected, `right` the main one.
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
        let core = makeCore()
        defer { PositionalDisplays.mainIDOverride = nil }
        let verb = "space_bar.set_edge"
        #expect(edge(core, verb, .string("left"), .number(1)).isSuccess)
        #expect(
            edge(core, verb, .string("right"), .string("Left")).isSuccess
        )
        // A screen that is not connected is stored as given.
        #expect(
            edge(core, verb, .string("bottom"), .string("Away:800x600"))
                .isSuccess
        )
        #expect(
            core.tiler.settings.spaceBarStyle.edgeOverride == [
                Self.right.fingerprint: .left,
                Self.left.fingerprint: .right,
                "Away:800x600": .bottom,
            ]
        )
        #expect(core.tiler.settings.spaceBarStyle.edge == .top)
        let refused = edge(core, verb, .string("left"), .string("Nope"))
        #expect(!refused.isSuccess)
        #expect(refused.error == KiwiCore.unknownScreen)
        #expect(
            core.tiler.settings.spaceBarStyle.edgeOverride.count
                == 3
        )
    }

    @Test("The bar's own edge follows; a screen-less edge clears all")
    func followAndClear() {
        let core = makeCore()
        defer { PositionalDisplays.mainIDOverride = nil }
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
        let core = makeCore()
        defer { PositionalDisplays.mainIDOverride = nil }
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

    @Test("A look sets the bars' edges and keeps each screen's own")
    func lookKeepsScreenEdges() {
        var settings = TilingSettings()
        settings.spaceBarStyle.setEdge(.left, on: Self.left.fingerprint)
        settings.appBarStyle.setEdge(.right, on: Self.left.fingerprint)
        let screens = (
            settings.spaceBarStyle.edgeOverride,
            settings.appBarStyle.edgeOverride
        )
        for bar in ["space_bar", "app_bar"] {
            ShelfLook.apply(
                path: "\(bar).edge",
                value: .string("bottom"),
                to: &settings
            )
        }
        #expect(settings.spaceBarStyle.edge == .bottom)
        #expect(settings.appBarStyle.edge == .bottom)
        #expect(settings.spaceBarStyle.edgeOverride == screens.0)
        #expect(settings.appBarStyle.edgeOverride == screens.1)
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
        #expect(
            !APIReference.retired.values.contains(
                .some("app_bar.set_edge_override")
            )
        )
    }
}
