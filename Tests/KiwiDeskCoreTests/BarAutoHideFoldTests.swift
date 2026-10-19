import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The visibility fold (#761) in `barEdges(space:app:)`: each bar
/// is handed its own value, an edge two bars share reads its more
/// present bar's, an `auto` edge reserves only its sliver and a
/// `hidden` one nothing, so a reveal draws over the windows.
@Suite("Bar visibility fold (#761)")
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
        settings.monocle.appBar.visibility = app
        settings.scrolling.appBar.visibility = app
        return settings
    }

    @Test("A lone auto bar's edge hides")
    func loneAutoHides() {
        let edges = settings(space: .auto, app: .always, appEdge: .bottom)
            .barEdges(space: .auto, app: nil)
        #expect(
            edges == [ShelfEdge(.top, reserves: true, bars: [.space: .auto])]
        )
        #expect(edges[0].hides)
    }

    @Test("A fused edge hides only while no bar on it is always")
    func fusedHidesOnlyTogether() {
        let base = TilingSettings()
        #expect(!base.barEdges(space: .auto, app: .always)[0].hides)
        #expect(!base.barEdges(space: .always, app: .auto)[0].hides)
        #expect(base.barEdges(space: .auto, app: .auto)[0].hides)
        #expect(base.barEdges(space: .auto, app: .hidden)[0].hides)
    }

    /// A layout switch moves windows only where the two layouts'
    /// App Bar values differ — the fold reads stored values, never
    /// what a layout draws.
    @Test("A layout switch moves nothing between equal App Bar values")
    func layoutSwitchIsValueBound() {
        let mixed = settings(space: .auto, app: .always)
        for mode in [LayoutMode.monocle, .scrolling] {
            #expect(mixed.shelfEdges(in: mode, on: nil) == [.top])
        }
        // A layout with no App Bar reads the Space Bar alone.
        #expect(mixed.shelfEdges(in: .bsp, on: nil).isEmpty)
        #expect(mixed.hidingEdges(in: .bsp, on: nil) == [.top])
        let both = settings(space: .auto, app: .auto)
        for mode in LayoutMode.allCases {
            #expect(both.shelfEdges(in: mode, on: nil).isEmpty)
            #expect(both.hidingEdges(in: mode, on: nil) == [.top])
        }
    }

    @Test("Each bar keeps its own value on a shared edge")
    func valuesAreNotLinked() {
        var shared = settings(space: .always, app: .always)
        shared.monocle.appBar.visibility = .auto
        #expect(shared.spaceBarStyle.visibility == .always)
        #expect(shared.appBarVisibility(in: .monocle) == .auto)
        #expect(shared.appBarVisibility(in: .scrolling) == .always)
    }

    @Test("Split bars hide on their own edges")
    func splitHidesApart() {
        let edges = settings(space: .auto, app: .always, appEdge: .bottom)
            .barEdges(space: .auto, app: .always)
        #expect(
            edges == [
                ShelfEdge(.top, reserves: true, bars: [.space: .auto]),
                ShelfEdge(.bottom, reserves: true, bars: [.app: .always]),
            ]
        )
    }

    /// The amendment (#761, owner 2026-10-18): a hidden shelf keeps
    /// a sliver laid out by the shelf's own rule, so its windows
    /// stand their outer gap clear of the dots.
    @Test("A hiding edge reserves the sliver, never the strip")
    func hidingEdgeReservesTheSliver() {
        var hidden = settings(space: .auto, app: .always, appEdge: .left)
        hidden.kiwishelf.outerMargin = 3
        hidden.kiwishelf.innerMargin = 5
        #expect(hidden.shelfEdges(in: .bsp, on: nil).isEmpty)
        #expect(hidden.hidingEdges(in: .bsp, on: nil) == [.top])
        let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let bounds = hidden.layoutBounds(from: visible, mode: .bsp, on: nil)
        #expect(
            visible.height - bounds.height == 3 + KiwiShelf.hiddenDepth + 5
        )
        hidden.spaceBarStyle.reserve = false
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
        let layouts = try #require(root["layout"] as? [String: Any])
        let monocle = try #require(layouts["monocle"] as? [String: Any])
        let app = try #require(monocle["app_bar"] as? [String: Any])
        let shelf = try #require(root["kiwishelf"] as? [String: Any])
        #expect(space["visibility"] as? String == "auto")
        #expect(app["visibility"] as? String == "auto")
        #expect(shelf["reveal_duration"] as? Double == 5)
        let back = try JSONDecoder().decode(TilingSettings.self, from: data)
        #expect(back.spaceBarStyle.visibility == .auto)
        #expect(back.monocle.appBar.visibility == .auto)
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
            "space_bar.visibility", "kiwishelf.reveal_duration",
        ] {
            #expect(!LookKeys.all.contains(key))
            #expect(LookKeys.leftOut[key] != nil)
        }
    }

    @Test("A bar's action is live wherever it is not always")
    func actionLiveness() {
        var settings = settings(space: .auto, app: .auto)
        #expect(settings.revealActionLive(.space, in: .bsp))
        settings.spaceBarStyle.visibility = .hidden
        #expect(settings.revealActionLive(.space, in: .bsp))
        settings.spaceBarStyle.visibility = .always
        #expect(!settings.revealActionLive(.space, in: .bsp))
        #expect(settings.revealActionLive(.app, in: .monocle))
        #expect(!settings.revealActionLive(.app, in: .bsp))
        settings.monocle.appBar.visibility = .always
        #expect(!settings.revealActionLive(.app, in: .monocle))
    }
}
