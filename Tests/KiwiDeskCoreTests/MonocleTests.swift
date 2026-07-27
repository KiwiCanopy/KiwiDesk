import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)

private func ids(_ n: Int) -> [WindowID] {
    (1...n).map { WindowID(UInt32($0)) }
}

private func makeContext(
    bounds: CGRect = CGRect(x: 0, y: 0, width: 1920, height: 1080),
    monocle: (inout MonocleParams) -> Void = { _ in }
) -> LayoutContext {
    var context = LayoutContext(
        bounds: bounds,
        gaps: .uniform(10)
    )
    monocle(&context.monocle)
    return context
}

@Suite("Monocle bar geometry")
struct MonocleGeometryTests {
    let layout = MonocleLayout()

    @Test("Bar disabled: every window fills the usable area")
    func barDisabled() throws {
        let context = makeContext { $0.appBar.enabled = false }
        let frames = layout.calculateGeometry(
            for: ids(3),
            in: context
        )
        for id in ids(3) {
            #expect(frames[id] == context.usable)
        }
    }

    @Test(
        "Bar strip and window never overlap and stay usable",
        arguments: [
            AppBarEdge.top, .bottom, .left, .right,
        ]
    )
    func stripCarving(edge: AppBarEdge) throws {
        // The edge is stored absolute (#293) — set it directly.
        let context = makeContext {
            $0.appBar.edge = edge
        }
        let usable = context.usable
        let bar = try #require(
            context.monocle.barFrame(in: usable, global: AppBarStyle())
        )
        let frames = layout.calculateGeometry(
            for: ids(2),
            in: context
        )
        let window = try #require(frames[w1])
        // All windows share the same frame.
        #expect(frames[w2] == window)
        // Both stay inside the usable area (no monitor bleed).
        #expect(usable.contains(bar))
        #expect(usable.contains(window))
        // The strip and the window never overlap.
        #expect(!bar.intersects(window))
        // The strip sits on the resolved edge.
        switch edge {
        case .top: #expect(bar.minY == usable.minY)
        case .bottom: #expect(bar.maxY == usable.maxY)
        case .left: #expect(bar.minX == usable.minX)
        case .right: #expect(bar.maxX == usable.maxX)
        }
        // One inner gap between strip and window.
        #expect(bar.height == 32 || bar.width == 32)
        if edge == .top {
            #expect(window.minY == bar.maxY + 10)
        }
    }

    @Test("Stored edge resolves absolute, override beats global")
    func edgeResolves() {
        var params = MonocleParams()
        // No override: the global edge wins.
        var global = AppBarStyle()
        global.edge = .right
        #expect(
            params.resolvedBar(global: global).edge == .right
        )
        // A per-layout override beats the global.
        params.appBar.edge = .left
        #expect(
            params.resolvedBar(global: global).edge == .left
        )
        // Orientation no longer affects the edge (#293).
        params.orientation = .horizontal
        #expect(
            params.resolvedBar(global: global).edge == .left
        )
    }

    @Test("Oversized thickness never produces negative frames")
    func oversizedThickness() throws {
        let context = makeContext {
            $0.appBar.thickness = 5000
        }
        let frames = layout.calculateGeometry(
            for: [w1],
            in: context
        )
        let window = try #require(frames[w1])
        #expect(window.width >= 0)
        #expect(window.height >= 0)
        let bar = try #require(
            context.monocle.barFrame(in: context.usable, global: AppBarStyle())
        )
        #expect(context.usable.contains(bar))
    }
}

@Suite("Monocle settings")
struct MonocleSettingsTests {
    @Test("Settings survive a profile JSON round-trip")
    func codableRoundTrip() throws {
        var settings = TilingSettings()
        settings.monocle.orientation = .vertical
        settings.monocle.appBar.enabled = false
        settings.monocle.appBar.edge = .bottom
        settings.monocle.appBar.thickness = 48
        settings.monocle.appBar.backgroundStyle = .plain
        settings.monocle.appBar.activeIndicator = .gap
        settings.monocle.appBar.itemSize = 90
        settings.monocle.appBar.itemGap = 0
        settings.monocle.appBar.content = .icon
        settings.monocle.appBar.highlightColor = "#FF0000"
        settings.monocle.appBar.groupAdjacentWindows = false
        settings.monocle.appBar.groupBadgeColor = "#112233"
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: data
        )
        #expect(decoded.monocle == settings.monocle)
    }

    @Test("Global style and per-layout overrides split in JSON")
    func nestedBarKey() throws {
        let data = try JSONEncoder().encode(TilingSettings())
        let json = try #require(
            try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
        // The global look sits top-level; item_size is a
        // concrete field there.
        let global = try #require(
            json["app_bar"] as? [String: Any]
        )
        #expect(global["item_size"] as? Double == 0)
        // The per-layout bar under monocle only carries its
        // own enabled flag until a field is overridden.
        let layout = try #require(
            json["layout"] as? [String: Any]
        )
        let monocle = try #require(
            layout["monocle"] as? [String: Any]
        )
        let bar = try #require(
            monocle["app_bar"] as? [String: Any]
        )
        #expect(bar["enabled"] as? Bool == true)
        #expect(bar["item_size"] == nil)
    }

    @Test("Profiles without a monocle key keep the defaults")
    func lenientDecoding() throws {
        let json = #"{"layout": {"monocle": {}}}"#
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data(json.utf8)
        )
        #expect(decoded.monocle == MonocleParams())
        #expect(decoded.monocle.appBar.enabled)
        // Nothing is overridden, so every look field inherits.
        #expect(decoded.monocle.appBar.itemSize == nil)
        #expect(decoded.monocle.orientation == .horizontal)
    }

    @Test("Partial bar objects override only the listed fields")
    func lenientBarDecoding() throws {
        let json = #"""
            {"layout": {"monocle": {
                "app_bar": {"item_size": 90}
            }}}
            """#
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data(json.utf8)
        )
        #expect(decoded.monocle.appBar.itemSize == 90)
        // Unlisted fields stay nil (inherit the global style).
        #expect(decoded.monocle.appBar.thickness == nil)
        #expect(decoded.monocle.appBar.enabled)
    }
}
