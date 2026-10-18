import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The auto-hide fold (#761) in `barEdges(space:app:)`: an edge
/// hides only while every bar on it is `auto`, and a hiding edge
/// reserves nothing, so a reveal draws over the windows.
@Suite("Bar auto-hide fold (#761)")
struct BarAutoHideFoldTests {
    private func settings(
        space: ShelfVisibility,
        app: ShelfVisibility,
        appEdge: AppBarEdge = .top
    ) -> TilingSettings {
        var settings = TilingSettings()
        settings.spaceBarStyle.setEdge(.top)
        settings.appBarStyle.setEdge(appEdge)
        settings.spaceBarStyle.visibility = space
        settings.appBarStyle.visibility = app
        return settings
    }

    @Test("A lone auto bar's edge hides and reserves nothing")
    func loneAutoHides() {
        let edges = settings(space: .auto, app: .always, appEdge: .bottom)
            .barEdges(space: true, app: false)
        #expect(edges == [ShelfEdge(.top, reserves: false, hides: true)])
    }

    @Test("A fused edge hides only while both bars are auto")
    func fusedHidesOnlyTogether() {
        let mixed = settings(space: .auto, app: .always)
            .barEdges(space: true, app: true)
        #expect(mixed == [ShelfEdge(.top, reserves: true, hides: false)])
        let otherMixed = settings(space: .always, app: .auto)
            .barEdges(space: true, app: true)
        #expect(
            otherMixed == [ShelfEdge(.top, reserves: true, hides: false)]
        )
        let both = settings(space: .auto, app: .auto)
            .barEdges(space: true, app: true)
        #expect(both == [ShelfEdge(.top, reserves: false, hides: true)])
    }

    /// The drift review found: a layout that draws no App Bar must
    /// not hide a shelf the App Bar shares by edge (#761 ruling).
    @Test("Linked bars hide alike in every layout")
    func linkedHideIsLayoutFree() {
        let mixed = settings(space: .auto, app: .always)
        #expect(mixed.barsLinked)
        for mode in LayoutMode.allCases {
            #expect(mixed.shelfEdges(in: mode, on: nil) == [.top])
        }
        let both = settings(space: .auto, app: .auto)
        for mode in LayoutMode.allCases {
            #expect(both.shelfEdges(in: mode, on: nil).isEmpty)
        }
    }

    @Test("A per-screen shared edge links the bars everywhere")
    func linkedOnAnyScreen() {
        var split = settings(space: .auto, app: .always, appEdge: .bottom)
        #expect(!split.barsLinked)
        #expect(split.visibility(of: .space) == .auto)
        split.appBarStyle.edgeOverride = ["S:1x1": .top]
        #expect(split.barsLinked)
        #expect(split.visibility(of: .space) == .always)
        #expect(split.onScreen(nil).spaceBarStyle.visibility == .always)
    }

    @Test("The write door writes both linked bars, one apart")
    func writeDoor() {
        var linked = settings(space: .always, app: .always)
        linked.setVisibility(.auto, of: .app)
        #expect(linked.spaceBarStyle.visibility == .auto)
        #expect(linked.appBarStyle.visibility == .auto)
        var apart = settings(space: .always, app: .always, appEdge: .left)
        apart.setVisibility(.auto, of: .app)
        #expect(apart.spaceBarStyle.visibility == .always)
        #expect(apart.appBarStyle.visibility == .auto)
    }

    @Test("Split bars hide on their own edges")
    func splitHidesApart() {
        let edges = settings(space: .auto, app: .always, appEdge: .bottom)
            .barEdges(space: true, app: true)
        #expect(
            edges == [
                ShelfEdge(.top, reserves: false, hides: true),
                ShelfEdge(.bottom, reserves: true, hides: false),
            ]
        )
    }

    @Test("A hiding edge leaves the layout bounds whole")
    func hidingEdgeReservesNothing() {
        let hidden = settings(space: .auto, app: .always, appEdge: .left)
        #expect(hidden.shelfEdges(in: .bsp, on: nil).isEmpty)
        let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)
        #expect(
            hidden.layoutBounds(from: visible, mode: .bsp, on: nil)
                == visible
        )
        let shown = settings(space: .always, app: .always)
        #expect(shown.shelfEdges(in: .bsp, on: nil) == [.top])
    }

    @Test("The mode and the reveal duration round-trip through JSON")
    func storedShape() throws {
        var settings = settings(space: .auto, app: .auto)
        settings.kiwishelf.revealDuration = 5
        let data = try JSONEncoder().encode(settings)
        let root = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let space = try #require(root["space_bar"] as? [String: Any])
        let app = try #require(root["app_bar"] as? [String: Any])
        let shelf = try #require(root["kiwishelf"] as? [String: Any])
        #expect(space["visibility"] as? String == "auto")
        #expect(app["visibility"] as? String == "auto")
        #expect(shelf["reveal_duration"] as? Double == 5)
        let back = try JSONDecoder().decode(TilingSettings.self, from: data)
        #expect(back.spaceBarStyle.visibility == .auto)
        #expect(back.appBarStyle.visibility == .auto)
        #expect(back.kiwishelf.revealDuration == 5)
    }

    @Test("An absent key keeps today's behaviour")
    func absentKeyIsAlways() throws {
        let style = try JSONDecoder().decode(
            SpaceBarStyle.self,
            from: Data("{}".utf8)
        )
        #expect(style.visibility == .always)
        let shelf = try JSONDecoder().decode(
            KiwiShelf.self,
            from: Data(#"{"reveal_duration": 500}"#.utf8)
        )
        #expect(shelf.revealDuration == 60)
    }

    @Test("The visibility mode is functionality, never a look's")
    func lookLeavesItOut() {
        for key in [
            "space_bar.visibility", "app_bar.visibility",
            "kiwishelf.reveal_duration",
        ] {
            #expect(!LookKeys.all.contains(key))
            #expect(LookKeys.leftOut[key] != nil)
        }
    }
}
