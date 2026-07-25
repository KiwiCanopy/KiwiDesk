import Foundation
import Testing

@testable import KiwiDeskCore

/// The Liquid Glass finish (#390): an orthogonal `liquidGlass`
/// bool over the `boxed | plain` shape, OS-gated by
/// `glassAvailable`. The actual glass rendering is AppKit and
/// OS-gated (exercised by hand); these pin the pure, portable
/// behavior — the gate, `hasBox`, round-trip, and command parse.
@Suite("Tab background — Liquid Glass")
struct BackgroundStyleGlassTests {
    @Test("glassEnabled gates the finish on OS capability")
    func glassGate() {
        var style = AppBarStyle()
        #expect(style.glassEnabled == false)  // default off
        style.liquidGlass = true
        // Effective only where the platform can render glass.
        #expect(style.glassEnabled == AppBarStyle.glassAvailable)
    }

    @Test("hasBox is the Boxed shape without the glass finish")
    func hasBox() {
        var style = AppBarStyle()
        style.backgroundStyle = .boxed
        #expect(style.hasBox == !style.glassEnabled)
        style.backgroundStyle = .plain
        #expect(style.hasBox == false)
    }

    @Test("liquid_glass round-trips through JSON")
    func roundTrip() throws {
        var style = AppBarStyle()
        style.liquidGlass = true
        style.backgroundStyle = .plain
        let data = try JSONEncoder().encode(style)
        let back = try JSONDecoder().decode(
            AppBarStyle.self,
            from: data
        )
        #expect(back.liquidGlass == true)
        #expect(back.backgroundStyle == .plain)
    }

    @Test("both bar parsers accept liquid_glass")
    func parseGlass() {
        let app = AppBarCommandSetting.parse(
            field: "liquid_glass",
            args: [.bool(true)]
        )
        guard case .success(let appSetting) = app else {
            Issue.record("app bar rejected liquid_glass")
            return
        }
        var appStyle = AppBarStyle()
        appSetting.apply(to: &appStyle)
        #expect(appStyle.liquidGlass == true)

        let space = SpaceBarCommandSetting.parse(
            field: "liquid_glass",
            args: [.bool(true)]
        )
        guard case .success(let spaceSetting) = space else {
            Issue.record("space bar rejected liquid_glass")
            return
        }
        var spaceStyle = SpaceBarStyle()
        spaceSetting.apply(to: &spaceStyle)
        #expect(spaceStyle.liquidGlass == true)
    }
}
