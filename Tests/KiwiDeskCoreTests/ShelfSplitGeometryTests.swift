import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Each bar owns its edge (#1731): the edges a layout reserves,
/// the strips at a corner, and the plans one per edge.
@Suite("Shelf split geometry (#1731)")
struct ShelfSplitGeometryTests {
    private let visible = CGRect(x: 0, y: 25, width: 1920, height: 1055)

    /// Space Bar on `space`, both layouts' App Bars on `app`.
    private func settings(
        space: AppBarEdge,
        app: AppBarEdge,
        spaceBar: Bool = true
    ) -> TilingSettings {
        var settings = TilingSettings()
        settings.kiwishelf.thickness = 32
        settings.spaceBarStyle.enabled = spaceBar
        settings.spaceBarStyle.edge = space
        settings.appBarStyle.edge = app
        settings.monocle.appBar.enabled = true
        settings.scrolling.appBar.enabled = true
        return settings
    }

    @Test("A layout reserves the edges its bars draw on")
    func edgesPerMode() {
        let split = settings(space: .top, app: .bottom)
        #expect(split.shelfEdges(in: .bsp) == [.top])
        #expect(split.shelfEdges(in: .monocle) == [.top, .bottom])
        #expect(split.shelfEdges(in: .scrolling) == [.top, .bottom])
        let fused = settings(space: .left, app: .left)
        #expect(fused.shelfEdges(in: .monocle) == [.left])
        #expect(fused.shelfEdges(in: .bsp) == [.left])
        let appOnly = settings(space: .top, app: .right, spaceBar: false)
        #expect(appOnly.shelfEdges(in: .monocle) == [.right])
        #expect(appOnly.shelfEdges(in: .bsp).isEmpty)
    }

    @Test("A split App Bar's strip leaves the layout in its layouts only")
    func splitReservationReflows() {
        let split = settings(space: .top, app: .bottom)
        let bsp = split.layoutBounds(from: visible, mode: .bsp)
        let monocle = split.layoutBounds(from: visible, mode: .monocle)
        #expect(bsp.minY == visible.minY + 32)
        #expect(bsp.maxY == visible.maxY)
        #expect(monocle.minY == visible.minY + 32)
        #expect(monocle.maxY == visible.maxY - 32)
    }

    @Test("At a corner the Space Bar runs the edge and the App Bar yields")
    func cornerYields() {
        var shelf = KiwiShelf()
        shelf.thickness = 32
        let strips = ShelfGeometry.strips(
            in: visible,
            edges: [.top, .left],
            shelf: shelf
        )
        #expect(strips.count == 2)
        #expect(strips[0].width == visible.width)
        #expect(strips[0].minY == visible.minY)
        #expect(strips[1].minX == visible.minX)
        #expect(strips[1].minY == visible.minY + 32)
        #expect(strips[1].maxY == visible.maxY)
        #expect(!strips[0].intersects(strips[1]))
    }

    @Test("sharedBarEdge names the one edge, or nil while split")
    func sharedEdge() {
        #expect(settings(space: .top, app: .top).sharedBarEdge == .top)
        #expect(settings(space: .top, app: .left).sharedBarEdge == nil)
    }
}

/// The live plan builds one shelf per edge (#1731).
@MainActor
@Suite("Shelf split plans (#1731)")
struct ShelfSplitPlanTests {
    private func items() -> [SpaceBarOverlay.Item] {
        (1...3).map {
            SpaceBarOverlay.Item(
                space: SpaceID("\($0)"),
                spaceGlyph: .text("\($0)", tinted: false),
                apps: [],
                active: $0 == 1,
                after: .none
            )
        }
    }

    private func app(_ settings: TilingSettings) -> KiwiCore.AppBarContent {
        let windows = (1...3).map {
            AppBarOverlay.Item(
                id: WindowID(UInt32($0)),
                text: "Window \($0)",
                icon: nil
            )
        }
        return KiwiCore.AppBarContent(
            space: Space(id: "s", windows: []),
            style: settings.appBarLook(for: settings.monocle.appBar),
            groups: windows.map { [$0.id] },
            items: windows
        )
    }

    private func plans(
        space: AppBarEdge,
        app appEdge: AppBarEdge
    ) -> [KiwiCore.ShelfPlan] {
        let core = makeTestCore()
        var settings = core.tiler.settings
        settings.spaceBarStyle.edge = space
        settings.appBarStyle.edge = appEdge
        return core.shelfPlans(
            visible: CGRect(x: 0, y: 0, width: 1600, height: 1000),
            settings: settings,
            spaceItems: items(),
            app: app(settings)
        )
    }

    /// The live plan's strips lie outside what the reservation
    /// leaves the layout, for the same settings: the two read one
    /// edge list (`barEdges`).
    @Test("A split plan's strips stay clear of the layout bounds")
    func stripsClearTheLayout() {
        let core = makeTestCore()
        var settings = core.tiler.settings
        settings.spaceBarStyle.enabled = true
        settings.monocle.appBar.enabled = true
        settings.spaceBarStyle.edge = .top
        settings.appBarStyle.edge = .left
        let visible = CGRect(x: 0, y: 0, width: 1600, height: 1000)
        let plans = core.shelfPlans(
            visible: visible,
            settings: settings,
            spaceItems: items(),
            app: app(settings)
        )
        #expect(plans.count == 2)
        let bounds = settings.layoutBounds(from: visible, mode: .monocle)
        for plan in plans {
            #expect(!plan.strip.intersects(bounds), "\(plan.edge)")
        }
    }

    @Test("Fused bars share one plan")
    func fusedIsOnePlan() throws {
        let plans = plans(space: .bottom, app: .bottom)
        #expect(plans.count == 1)
        let plan = try #require(plans.first)
        #expect(plan.edge == .bottom)
        #expect(plan.arrangement.space != nil)
        #expect(plan.arrangement.app != nil)
    }

    @Test("Split bars take a plan each, the Space Bar's first")
    func splitIsTwoPlans() throws {
        let plans = plans(space: .top, app: .right)
        #expect(plans.map(\.edge) == [.top, .right])
        let space = try #require(plans.first)
        let app = try #require(plans.last)
        #expect(space.arrangement.space != nil)
        #expect(space.arrangement.app == nil)
        #expect(space.arrangement.divider == nil)
        #expect(app.arrangement.app != nil)
        #expect(app.arrangement.space == nil)
        #expect(!app.horizontal)
        // The App Bar yields at the corner the two edges share.
        #expect(app.strip.minY == space.strip.maxY)
    }
}
