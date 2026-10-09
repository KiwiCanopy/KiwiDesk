import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A bar's edge per screen (#1948), as data: a screen's own edge
/// wins, any other screen uses the bar's, the bar's own edge is
/// never stored, and the entries collapse into the bar's edge
/// once every screen agrees. The reservation reads the resolved
/// edges through the one fold.
@Suite("Per-screen bar edges (#1948)")
struct ScreenEdgeTests {
    static let studio = "Studio Display:5120x2880"
    static let laptop = "Built-in Retina Display:1512x982"
    private let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)

    /// Both bars on the top edge, 32 pt deep, the Space Bar's
    /// edge on `studio` set to `studioEdge`.
    private func settings(studioEdge: AppBarEdge) -> TilingSettings {
        var settings = TilingSettings()
        settings.barEdge = .top
        settings.kiwishelf.thickness = 32
        settings.kiwishelf.outerMargin = 0
        settings.kiwishelf.innerMargin = 0
        settings.spaceBarStyle.setEdge(studioEdge, on: Self.studio)
        return settings
    }

    @Test("A screen's own edge wins; any other uses the bar's")
    func resolution() {
        var style = SpaceBarStyle()
        style.edge = .top
        style.setEdge(.left, on: Self.studio)
        #expect(style.edge(on: Self.studio) == .left)
        #expect(style.edge(on: Self.laptop) == .top)
        #expect(style.edge(on: "Unknown:640x480") == .top)
        #expect(style.edge(on: nil) == .top)
    }

    @Test("Picking the bar's own edge stores nothing")
    func barEdgeFollows() {
        var style = AppBarStyle()
        style.setEdge(.top, on: Self.studio)
        #expect(style.edgeOverride.isEmpty)
        style.setEdge(.right, on: Self.studio)
        #expect(style.edgeOverride == [Self.studio: .right])
        style.setEdge(.top, on: Self.studio)
        #expect(style.edgeOverride.isEmpty)
    }

    @Test("A screen-less edge clears every screen's own")
    func screenlessClears() {
        var style = SpaceBarStyle()
        style.setEdge(.left, on: Self.studio)
        style.setEdge(.right, on: Self.laptop)
        style.setEdge(.bottom)
        #expect(style.edge == .bottom)
        #expect(style.edgeOverride.isEmpty)
    }

    @Test("Entries collapse into the bar's edge once every screen agrees")
    func collapse() {
        let both: Set = [Self.studio, Self.laptop]
        var style = SpaceBarStyle()
        style.setEdge(.left, on: Self.studio)
        // The laptop still follows the bar: nothing collapses.
        style.collapseScreenEdges(among: both)
        #expect(style.edge == .top)
        #expect(style.edgeOverride == [Self.studio: .left])
        // One screen alone says nothing about a later screen.
        style.collapseScreenEdges(among: [Self.studio])
        #expect(style.edge == .top)
        style.setEdge(.left, on: Self.laptop)
        style.collapseScreenEdges(among: both)
        #expect(style.edge == .left)
        #expect(style.edgeOverride.isEmpty)
        // Disagreeing entries never collapse.
        style.setEdge(.right, on: Self.studio)
        style.setEdge(.bottom, on: Self.laptop)
        style.collapseScreenEdges(among: both)
        #expect(style.edge == .left)
        #expect(style.edgeOverride.count == 2)
    }

    @Test("The reserved edges are each screen's own")
    func reservationPerScreen() {
        let settings = settings(studioEdge: .left)
        #expect(settings.shelfEdges(in: .bsp, on: Self.studio) == [.left])
        #expect(settings.shelfEdges(in: .bsp, on: Self.laptop) == [.top])
        #expect(settings.shelfEdges(in: .bsp, on: nil) == [.top])
        let studio = settings.layoutBounds(
            from: visible,
            mode: .bsp,
            on: Self.studio
        )
        let laptop = settings.layoutBounds(
            from: visible,
            mode: .bsp,
            on: Self.laptop
        )
        #expect(studio.minX == visible.minX + 32)
        #expect(studio.minY == visible.minY)
        #expect(laptop.minX == visible.minX)
        #expect(laptop.minY == visible.minY + 32)
    }

    /// The App Bar fuses with the Space Bar on one screen and
    /// splits from it on another — the one fold, per screen.
    @Test("One screen fuses the bars, another splits them")
    func foldPerScreen() {
        var settings = settings(studioEdge: .top)
        settings.monocle.appBar.enabled = true
        settings.appBarStyle.setEdge(.bottom, on: Self.studio)
        #expect(
            settings.shelfEdges(in: .monocle, on: Self.studio)
                == [.top, .bottom]
        )
        #expect(settings.shelfEdges(in: .monocle, on: Self.laptop) == [.top])
        let studio = settings.onScreen(Self.studio)
        #expect(studio.spaceBarStyle.edge == .top)
        #expect(studio.appBarStyle.edge == .bottom)
        #expect(settings.onScreen(nil) == settings)
    }
}
