import Foundation
import Testing

@testable import KiwiDeskCore

/// The Liquid Glass `tab_background` case (#390): its render
/// fallback, round-trip, and command parse. The actual glass
/// rendering is AppKit and OS-gated, so it's exercised by hand;
/// these pin the pure, portable behavior.
@Suite("Tab background — Liquid Glass")
struct TabBackgroundGlassTests {
    typealias TB = AppBarStyle.TabBackground

    @Test("material renders as boxed only where glass is missing")
    func renderFallback() {
        #expect(TB.material.rendered(glassAvailable: false) == .boxed)
        #expect(
            TB.material.rendered(glassAvailable: true) == .material
        )
        // boxed and plain are unaffected either way.
        for base in [TB.boxed, .plain] {
            #expect(base.rendered(glassAvailable: false) == base)
            #expect(base.rendered(glassAvailable: true) == base)
        }
    }

    @Test("tab_background round-trips material through JSON")
    func roundTrip() throws {
        var style = AppBarStyle()
        style.tabBackground = .material
        let data = try JSONEncoder().encode(style)
        let back = try JSONDecoder().decode(
            AppBarStyle.self,
            from: data
        )
        #expect(back.tabBackground == .material)
    }

    @Test("both bar parsers accept material")
    func parseMaterial() {
        let app = AppBarCommandSetting.parse(
            field: "tab_background",
            args: [.string("material")]
        )
        guard case .success(let appSetting) = app else {
            Issue.record("app bar rejected material")
            return
        }
        var appStyle = AppBarStyle()
        appSetting.apply(to: &appStyle)
        #expect(appStyle.tabBackground == .material)

        let space = SpaceBarCommandSetting.parse(
            field: "tab_background",
            args: [.string("material")]
        )
        guard case .success(let spaceSetting) = space else {
            Issue.record("space bar rejected material")
            return
        }
        var spaceStyle = SpaceBarStyle()
        spaceSetting.apply(to: &spaceStyle)
        #expect(spaceStyle.tabBackground == .material)
    }
}
