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
    monocle: (inout MonocleParams) -> Void = { _ in },
    shelf: (inout KiwiShelf) -> Void = { _ in }
) -> LayoutContext {
    var context = LayoutContext(
        bounds: bounds,
        gaps: .uniform(10)
    )
    // Pinned (#660): the strip arithmetic below reasons from it.
    context.appBarStyle.thickness = 32
    shelf(&context.appBarStyle.shelf)
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
        // The edge is the shelf's, stored absolute (#293, #1517).
        let context = makeContext(shelf: { $0.edge = edge })
        let usable = context.usable
        let bounds = context.bounds
        let bar = try #require(
            context.monocle.barFrame(
                in: bounds,
                global: context.appBarStyle
            )
        )
        let frames = layout.calculateGeometry(
            for: ids(2),
            in: context
        )
        let window = try #require(frames[w1])
        // All windows share the same frame.
        #expect(frames[w2] == window)
        // Both stay inside the bounds (no monitor bleed); the
        // window inside the usable area.
        #expect(bounds.contains(bar))
        #expect(usable.contains(window))
        // The strip and the window never overlap.
        #expect(!bar.intersects(window))
        // The strip sits flush on the resolved edge of the
        // BOUNDS — its outer margin defaults to 0 (#1516).
        switch edge {
        case .top: #expect(bar.minY == bounds.minY)
        case .bottom: #expect(bar.maxY == bounds.maxY)
        case .left: #expect(bar.minX == bounds.minX)
        case .right: #expect(bar.maxX == bounds.maxX)
        }
        // The windows' OUTER gap between strip and window — the
        // bar reads no inner gap (#1516).
        #expect(bar.height == 32 || bar.width == 32)
        if edge == .top {
            #expect(window.minY == bar.maxY + 10)
        }
    }

    @Test("The shelf's edge resolves absolute, orientation aside")
    func edgeResolves() {
        var params = MonocleParams()
        var global = AppBarLook()
        global.edge = .right
        #expect(
            params.resolvedBar(global: global).edge == .right
        )
        // Orientation never affects the edge (#293).
        params.orientation = .vertical
        #expect(
            params.resolvedBar(global: global).edge == .right
        )
    }

    @Test("Oversized thickness never produces negative frames")
    func oversizedThickness() throws {
        var context = makeContext()
        context.appBarStyle.thickness = 5000
        let frames = layout.calculateGeometry(
            for: [w1],
            in: context
        )
        let window = try #require(frames[w1])
        #expect(window.width >= 0)
        #expect(window.height >= 0)
        let bar = try #require(
            context.monocle.barFrame(
                in: context.bounds,
                global: context.appBarStyle
            )
        )
        #expect(context.bounds.contains(bar))
    }
}

@Suite("Monocle settings")
struct MonocleSettingsTests {
    @Test("Settings survive a profile JSON round-trip")
    func codableRoundTrip() throws {
        var settings = TilingSettings()
        settings.monocle.orientation = .vertical
        settings.monocle.appBar.enabled = false
        settings.monocle.appBar.activeIndicator = .gap
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
        // The global look sits top-level; title_cap is a
        // concrete field there.
        let global = try #require(
            json["app_bar"] as? [String: Any]
        )
        #expect(global["title_cap"] as? Int == 10)
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
        #expect(bar["title_cap"] == nil)
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
        #expect(decoded.monocle.appBar.titleCap == nil)
        #expect(decoded.monocle.orientation == .horizontal)
    }

    @Test("Partial bar objects override only the listed fields")
    func lenientBarDecoding() throws {
        let json = #"""
            {"layout": {"monocle": {
                "app_bar": {"title_cap": 30}
            }}}
            """#
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data(json.utf8)
        )
        #expect(decoded.monocle.appBar.titleCap == 30)
        // Unlisted fields stay nil (inherit the global style).
        #expect(decoded.monocle.appBar.content == nil)
        #expect(decoded.monocle.appBar.enabled)
    }
}
