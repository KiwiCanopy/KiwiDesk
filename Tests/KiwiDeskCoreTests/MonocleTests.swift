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

    /// The shelf reserves its strip before the layout runs
    /// (`TilingSettings.layoutBounds(from:)`, #1517), so the
    /// App Bar's switch no longer moves a window: the frames are
    /// the usable area either way.
    @Test(
        "Every window fills the usable area, App Bar on or off",
        arguments: [true, false]
    )
    func fillsUsable(barEnabled: Bool) throws {
        let context = makeContext { $0.appBar.enabled = barEnabled }
        let frames = layout.calculateGeometry(
            for: ids(3),
            in: context
        )
        for id in ids(3) {
            #expect(frames[id] == context.usable)
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
}

@Suite("Monocle settings")
struct MonocleSettingsTests {
    @Test("Settings survive a profile JSON round-trip")
    func codableRoundTrip() throws {
        var settings = TilingSettings()
        settings.monocle.orientation = .vertical
        settings.monocle.appBar.enabled = false
        settings.monocle.appBar.activeIndicator = .outline
        settings.monocle.appBar.content = .icon
        settings.monocle.appBar.titleCap = 7
        settings.monocle.appBar.groupAdjacentWindows = false
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
