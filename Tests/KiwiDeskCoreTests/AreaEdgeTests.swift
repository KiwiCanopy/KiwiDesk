import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A bar's edge differs per area (#3517 rulings 7, 14, 16, 22, 30):
/// reads are exact — an entry applies to its own key, the bare
/// fingerprint being area 0's — and the fan-out is the write's: a
/// physical screen named by number or name writes every area of it,
/// a fingerprint or area key writes that one area.
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
        core.state.workspaces.upsertDisplay(wide)
        var settings = core.tiler.settings
        settings.displayAreas.store(
            try threeAreas(),
            on: fp,
            order: core.liveScreenOrder
        )
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
                .splits(order: core.liveScreenOrder, floors: .unfloored)
        )
        #expect(keys == [fp, "\(fp)#1", "\(fp)#2"])
        #expect(
            core.liveScreenEdgeScope.screens.isSuperset(of: Set(keys))
        )
    }

    @Test("an area's edge is its own entry, else the bar's")
    func lookupIsExact() {
        var style = SpaceBarStyle()
        style.setEdge(.top)
        style.edgeOverride = [fp: .left]
        #expect(style.edge(on: fp) == .left)
        #expect(style.edge(on: "\(fp)#1") == .top)
        style.edgeOverride["\(fp)#1"] = .bottom
        #expect(style.edge(on: "\(fp)#1") == .bottom)
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

    @Test("a fingerprint writes area 0 alone")
    func fingerprintWritesAreaZero() throws {
        let core = try core()
        core.execute(
            "space_bar.set_edge",
            args: [.string("left"), .string(fp)]
        )
        let style = core.tiler.settings.spaceBarStyle
        #expect(style.edgeOverride == [fp: .left])
        #expect(style.edge(on: "\(fp)#1") == .top)
        #expect(style.edge(on: "\(fp)#2") == .top)
    }

    @Test("a physical screen, by number or name, writes every area")
    func physicalScreenWritesEveryArea() throws {
        for screen in [JSONValue.number(1), .string("Wide")] {
            let core = try core()
            core.execute(
                "space_bar.set_edge",
                args: [.string("bottom"), .string("Other:100x100")]
            )
            let set = core.execute(
                "space_bar.set_edge",
                args: [.string("bottom"), screen]
            )
            #expect(set.isSuccess, "\(screen)")
            let style = core.tiler.settings.spaceBarStyle
            for key in [fp, "\(fp)#1", "\(fp)#2"] {
                #expect(style.edge(on: key) == .bottom, "\(screen) \(key)")
            }
        }
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
}
