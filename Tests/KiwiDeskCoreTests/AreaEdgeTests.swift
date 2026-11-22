import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A bar's edge differs per area (#3517 rulings 7, 22, 30): one
/// lookup model — an area's own entry, else its screen's, else the
/// bar's — written so no write moves an area it did not name, by
/// Settings and by `set_edge`'s screen argument alike.
@Suite("Area edges (#3517)")
@MainActor
struct AreaEdgeTests {
    private let wide = Display(
        id: DisplayID(900_811),
        name: "Wide",
        frame: CGRect(x: 0, y: 0, width: 3440, height: 1440)
    )

    private var fp: String { wide.fingerprint }

    /// The wide screen split into three areas side by side.
    private func threeAreas() throws -> ScreenSplit {
        let two = try #require(
            ScreenSplit.whole(width: 3440, height: 1440)
                .splitting(0, .sideBySide)
        )
        return try #require(two.splitting(1, .sideBySide))
    }

    private func core() throws -> KiwiCore {
        let core = makeTestCore()
        core.honoursAreaSplits = true
        core.state.workspaces.upsertDisplay(wide)
        var settings = core.tiler.settings
        settings.displayAreas = [fp: try threeAreas()]
        settings.spaceBarStyle.setEdge(.top)
        core.tiler.settings = settings
        return core
    }

    @Test("the scope holds every area of a split screen")
    func scopeHoldsTheAreas() throws {
        let core = try core()
        let keys = ScreenSplit.areaKeys(
            of: fp,
            in: core.tiler.settings.displayAreas
        )
        #expect(keys == [fp, "\(fp)#1", "\(fp)#2"])
        #expect(
            core.liveScreenEdgeScope.screens.isSuperset(of: Set(keys))
        )
    }

    @Test("an area's edge falls back to its screen's, then the bar's")
    func lookupFallsBack() {
        var style = SpaceBarStyle()
        style.setEdge(.top)
        style.edgeOverride = [fp: .left]
        #expect(style.edge(on: "\(fp)#1") == .left)
        style.edgeOverride["\(fp)#1"] = .bottom
        #expect(style.edge(on: "\(fp)#1") == .bottom)
        #expect(style.edge(on: "Other:100x100#1") == .top)
    }

    @Test("setting area 1 leaves areas 0 and 2 where they were")
    func middleAreaMovesAlone() throws {
        let core = try core()
        let set = core.execute(
            "space_bar.set_edge",
            args: [.string("bottom"), .string("\(fp)#1")]
        )
        #expect(set.isSuccess)
        let style = core.tiler.settings.spaceBarStyle
        #expect(style.edgeOverride == ["\(fp)#1": .bottom])
        #expect(style.edge(on: fp) == .top)
        #expect(style.edge(on: "\(fp)#2") == .top)
    }

    @Test("setting a screen's own key pins its other areas")
    func screenKeyPinsTheAreas() throws {
        let core = try core()
        core.execute(
            "space_bar.set_edge",
            args: [.string("bottom"), .string("\(fp)#1")]
        )
        core.execute(
            "space_bar.set_edge",
            args: [.string("left"), .string(fp)]
        )
        let style = core.tiler.settings.spaceBarStyle
        #expect(style.edge(on: fp) == .left)
        #expect(style.edge(on: "\(fp)#1") == .bottom)
        #expect(style.edge(on: "\(fp)#2") == .top)
    }

    @Test("entries collapse only once every area agrees")
    func collapseJudgesEveryArea() throws {
        let core = try core()
        for area in [fp, "\(fp)#1"] {
            core.execute(
                "space_bar.set_edge",
                args: [.string("bottom"), .string(area)]
            )
        }
        var style = core.tiler.settings.spaceBarStyle
        #expect(style.edge == .top)
        #expect(style.edge(on: "\(fp)#2") == .top)
        core.execute(
            "space_bar.set_edge",
            args: [.string("bottom"), .string("\(fp)#2")]
        )
        style = core.tiler.settings.spaceBarStyle
        #expect(style.edge == .bottom)
        #expect(style.edgeOverride.isEmpty)
    }

    /// An area key stores nothing where it asks for its screen's
    /// edge; a screen key's own entry is kept on a repeat write of
    /// the same edge, and its next write pins the area where it was.
    @Test("each key stores only what it would not inherit")
    func keysStoreOnlyTheirOwn() {
        let scope = ScreenEdgeScope(
            screens: [fp, "\(fp)#1", "\(fp)#2", "Other:100x100"]
        )
        var style = SpaceBarStyle()
        style.setEdge(.top)
        style.setEdge(.left, on: fp, among: scope)
        style.setEdge(.left, on: "\(fp)#1", among: scope)
        #expect(style.edgeOverride["\(fp)#1"] == nil)
        style.setEdge(.bottom, on: fp, among: scope)
        style.setEdge(.bottom, on: fp, among: scope)
        #expect(style.edgeOverride[fp] == .bottom)
        #expect(style.edge(on: "\(fp)#1") == .left)
    }
}
