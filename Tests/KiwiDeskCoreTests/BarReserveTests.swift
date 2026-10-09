import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Shown apart from reserved (#1524): `barEdges` lists every edge
/// a shown bar sits on, each carrying whether the layout gives it
/// up — OR-folded where two bars share an edge — and
/// `shelfEdges(in:)` keeps the reserving ones alone.
@Suite("Bar reserve (#1524)")
struct BarReserveTests {
    private let visible = CGRect(x: 0, y: 25, width: 1920, height: 1055)

    /// Space Bar on `space`, both layouts' App Bars on `app`.
    private func settings(
        space: AppBarEdge,
        app: AppBarEdge,
        spaceReserves: Bool = true,
        appReserves: Bool = true
    ) -> TilingSettings {
        var settings = TilingSettings()
        settings.kiwishelf.thickness = 32
        settings.spaceBarStyle.enabled = true
        settings.spaceBarStyle.edge = space
        settings.spaceBarStyle.reserve = spaceReserves
        settings.appBarStyle.edge = app
        settings.appBarStyle.reserve = appReserves
        settings.monocle.appBar.enabled = true
        settings.scrolling.appBar.enabled = true
        return settings
    }

    @Test("A shared edge reserves while either bar on it does")
    func fusedEdgeOrs() {
        let both = settings(space: .top, app: .top)
        #expect(both.shelfEdges(in: .monocle) == [.top])
        let spaceOff = settings(
            space: .top,
            app: .top,
            spaceReserves: false
        )
        #expect(spaceOff.shelfEdges(in: .monocle) == [.top])
        // Where no App Bar draws, the Space Bar's own flag rules.
        #expect(spaceOff.shelfEdges(in: .bsp).isEmpty)
        let appOff = settings(space: .top, app: .top, appReserves: false)
        #expect(appOff.shelfEdges(in: .monocle) == [.top])
        let neither = settings(
            space: .top,
            app: .top,
            spaceReserves: false,
            appReserves: false
        )
        #expect(neither.shelfEdges(in: .monocle).isEmpty)
        #expect(
            neither.layoutBounds(from: visible, mode: .monocle)
                == visible
        )
    }

    @Test("Split edges reserve independently")
    func splitEdgesIndependent() {
        // The owner's case: the Space Bar over the windows at the
        // top, the App Bar reserving the bottom.
        let split = settings(
            space: .top,
            app: .bottom,
            spaceReserves: false
        )
        #expect(split.shelfEdges(in: .bsp).isEmpty)
        #expect(split.shelfEdges(in: .monocle) == [.bottom])
        let bounds = split.layoutBounds(from: visible, mode: .monocle)
        #expect(bounds.minY == visible.minY)
        #expect(bounds.maxY == visible.maxY - 32)
    }

    @Test("Every shown edge stays in the drawn list")
    func shownEdgesStayListed() {
        let neither = settings(
            space: .top,
            app: .bottom,
            spaceReserves: false,
            appReserves: false
        )
        #expect(
            neither.barEdges(space: true, app: true)
                == [
                    ShelfEdge(.top, reserves: false),
                    ShelfEdge(.bottom, reserves: false),
                ]
        )
    }

    @Test("reserve round-trips through the profile JSON")
    func jsonRoundTrip() throws {
        let json = """
            {"space_bar": {"reserve": false},
             "app_bar": {"reserve": false}}
            """
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data(json.utf8)
        )
        #expect(!decoded.spaceBarStyle.reserve)
        #expect(!decoded.appBarStyle.reserve)
        let again = try JSONDecoder().decode(
            TilingSettings.self,
            from: JSONEncoder().encode(decoded)
        )
        #expect(!again.spaceBarStyle.reserve)
        #expect(!again.appBarStyle.reserve)
        // Absent is today's behaviour: the strip is reserved.
        let sparse = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data(#"{"space_bar": {}, "app_bar": {}}"#.utf8)
        )
        #expect(sparse.spaceBarStyle.reserve)
        #expect(sparse.appBarStyle.reserve)
    }
}
