import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A bar's edge per screen (#1948), as data: a screen's own edge
/// wins, any other screen uses the bar's, the bar's own edge is
/// never stored, and the entries collapse into the bar's edge
/// once every screen of the judged set agrees. The reservation
/// reads the resolved edges through the one fold.
@Suite("Per-screen bar edges (#1948)")
struct ScreenEdgeTests {
    static let studio = "Studio Display:5120x2880"
    static let laptop = "Built-in Retina Display:1512x982"
    static let away = "LG HDR 4K:3840x2160"
    private let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)

    /// Both bars on the top edge, 32 pt deep, the Space Bar's
    /// edge on `studio` set to `studioEdge`.
    private func settings(studioEdge: AppBarEdge) -> TilingSettings {
        var settings = TilingSettings()
        settings.barEdge = .top
        settings.kiwishelf.thickness = 32
        settings.kiwishelf.outerMargin = 0
        settings.kiwishelf.innerMargin = 0
        settings.spaceBarStyle.setEdge(
            studioEdge,
            on: Self.studio,
            among: ScreenEdgeScope(screens: [Self.studio, Self.laptop])
        )
        return settings
    }

    @Test("A screen's own edge wins; any other uses the bar's")
    func resolution() {
        var style = SpaceBarStyle()
        style.edge = .top
        style.setEdge(
            .left,
            on: Self.studio,
            among: ScreenEdgeScope(screens: [Self.laptop])
        )
        #expect(style.edge(on: Self.studio) == .left)
        #expect(style.edge(on: Self.laptop) == .top)
        #expect(style.edge(on: "Unknown:640x480") == .top)
        #expect(style.edge(on: nil) == .top)
        #expect(style.screensDiffer)
    }

    @Test("Picking the bar's own edge stores nothing")
    func barEdgeFollows() {
        let both: Set = [Self.studio, Self.laptop]
        var style = AppBarStyle()
        style.setEdge(
            .top,
            on: Self.studio,
            among: ScreenEdgeScope(screens: both)
        )
        #expect(style.edgeOverride.isEmpty)
        style.setEdge(
            .right,
            on: Self.studio,
            among: ScreenEdgeScope(screens: both)
        )
        #expect(style.edgeOverride == [Self.studio: .right])
        style.setEdge(
            .top,
            on: Self.studio,
            among: ScreenEdgeScope(screens: both)
        )
        #expect(style.edgeOverride.isEmpty)
    }

    @Test("A screen-less edge clears every screen's own")
    func screenlessClears() {
        var style = SpaceBarStyle()
        let all: Set = [Self.studio, Self.laptop, Self.away]
        style.setEdge(
            .left,
            on: Self.studio,
            among: ScreenEdgeScope(screens: all)
        )
        style.setEdge(
            .right,
            on: Self.laptop,
            among: ScreenEdgeScope(screens: all)
        )
        style.setEdge(.bottom)
        #expect(style.edge == .bottom)
        #expect(style.edgeOverride.isEmpty)
    }

    /// The judged set is the screens handed in plus the entries'
    /// own: a known screen that follows the bar blocks the
    /// collapse, and with none the entries alone decide.
    @Test("Entries collapse once every judged screen agrees")
    func collapse() {
        let both: Set = [Self.studio, Self.laptop]
        var style = SpaceBarStyle()
        style.setEdge(
            .left,
            on: Self.studio,
            among: ScreenEdgeScope(screens: both)
        )
        // The laptop still follows the bar: nothing collapses.
        #expect(style.edge == .top)
        #expect(style.edgeOverride == [Self.studio: .left])
        style.setEdge(
            .left,
            on: Self.laptop,
            among: ScreenEdgeScope(screens: both)
        )
        #expect(style.edge == .left)
        #expect(style.edgeOverride.isEmpty)
        // A screen of the set beyond the entries blocks it.
        let three = both.union([Self.away])
        style.setEdge(
            .right,
            on: Self.studio,
            among: ScreenEdgeScope(screens: three)
        )
        style.setEdge(
            .right,
            on: Self.laptop,
            among: ScreenEdgeScope(screens: three)
        )
        #expect(style.edge == .left)
        #expect(style.edgeOverride.count == 2)
        // With no other screen known, the one entry decides.
        var lone = SpaceBarStyle()
        lone.setEdge(
            .left,
            on: Self.studio,
            among: ScreenEdgeScope(screens: [])
        )
        #expect(lone.edge == .left)
        #expect(lone.edgeOverride.isEmpty)
        // Disagreeing entries never collapse.
        style.setEdge(
            .bottom,
            on: Self.away,
            among: ScreenEdgeScope(screens: three)
        )
        #expect(style.edgeOverride.count == 3)
    }

    @Test("A look keeps every screen's own, even one it equals")
    func lookKeepsScreens() {
        var style = SpaceBarStyle()
        style.edgeOverride = [Self.studio: .left, Self.laptop: .right]
        style.setEdgeKeepingScreens(.left)
        #expect(style.edge == .left)
        #expect(
            style.edgeOverride == [Self.studio: .left, Self.laptop: .right]
        )
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
        settings.appBarStyle.setEdge(
            .bottom,
            on: Self.studio,
            among: ScreenEdgeScope(screens: [Self.studio, Self.laptop])
        )
        #expect(
            settings.shelfEdges(in: .monocle, on: Self.studio)
                == [.top, .bottom]
        )
        #expect(settings.shelfEdges(in: .monocle, on: Self.laptop) == [.top])
        let studio = settings.onScreen(Self.studio)
        #expect(studio.spaceBarStyle.edge == .top)
        #expect(studio.appBarStyle.edge == .bottom)
        // A resolved copy holds no entry: resolving it again is
        // a fixed point.
        #expect(!studio.hasScreenEdges)
        #expect(studio.onScreen(Self.laptop) == studio)
    }

    /// A pin a look left equal to the bar's edge draws that edge:
    /// the Position master selects it, and a later write that
    /// makes every screen draw it collapses, moving no screen.
    @Test("Judgements read the edge each screen draws")
    func judgementsReadDrawnEdges() {
        let both = ScreenEdgeScope(screens: [Self.studio, Self.laptop])
        var settings = TilingSettings()
        settings.barEdge = .bottom
        settings.spaceBarStyle.setEdge(.top, on: Self.studio, among: both)
        settings.appBarStyle.setEdge(.top, on: Self.studio, among: both)
        #expect(settings.uniformBarEdge == nil)
        // A look sets top and keeps the studio's pin.
        settings.spaceBarStyle.setEdgeKeepingScreens(.top)
        settings.appBarStyle.setEdgeKeepingScreens(.top)
        #expect(settings.spaceBarStyle.edgeOverride == [Self.studio: .top])
        #expect(settings.uniformBarEdge == .top)
        // The laptop's write of the bar's edge stores nothing, and
        // every screen drawing top collapses the pin.
        settings.spaceBarStyle.setEdge(.top, on: Self.laptop, among: both)
        #expect(settings.spaceBarStyle.edge == .top)
        #expect(settings.spaceBarStyle.edgeOverride.isEmpty)
        for screen in [Self.studio, Self.laptop] {
            #expect(settings.spaceBarStyle.edge(on: screen) == .top)
        }
    }

    /// A write of the bar's own edge stores nothing for that
    /// screen, so a later bar edge moves it.
    @Test("A screen given the bar's edge follows the bar")
    func barEdgeWriteStoresNothing() {
        let both = ScreenEdgeScope(screens: [Self.studio, Self.laptop])
        var style = SpaceBarStyle()
        style.edgeOverride = [Self.studio: .left]
        style.setEdge(.top, on: Self.laptop, among: both)
        #expect(style.edgeOverride == [Self.studio: .left])
        style.setEdgeKeepingScreens(.bottom)
        #expect(style.edge(on: Self.laptop) == .bottom)
    }

    /// A write that clears its own entry outside the scope still
    /// judges that screen: it draws the bar's edge, so another
    /// screen's edge never collapses onto it.
    @Test("The written screen is judged though the scope lacks it")
    func writtenScreenIsJudged() {
        var style = SpaceBarStyle()
        style.setEdge(.bottom)
        style.edgeOverride = [Self.studio: .top, Self.away: .top]
        style.setEdge(
            .bottom,
            on: Self.away,
            among: ScreenEdgeScope(screens: [Self.studio])
        )
        #expect(style.edge == .bottom)
        #expect(style.edgeOverride == [Self.studio: .top])
        #expect(style.edge(on: Self.away) == .bottom)
    }

    /// The Position master selects an edge only while the bars
    /// share it on every screen.
    @Test("A screen of its own leaves the Position master unset")
    func uniformEdge() {
        var settings = TilingSettings()
        settings.barEdge = .left
        #expect(settings.uniformBarEdge == .left)
        settings.appBarStyle.setEdge(
            .right,
            on: Self.studio,
            among: ScreenEdgeScope(screens: [Self.studio, Self.laptop])
        )
        #expect(settings.sharedBarEdge == .left)
        #expect(settings.uniformBarEdge == nil)
    }
}
