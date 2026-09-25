import Foundation
import Testing

@testable import KiwiDeskCore

/// The Liquid Glass finish (#390): an orthogonal `liquidGlass`
/// bool over the `boxed | plain` shape, OS-gated by
/// `glassAvailable`. The actual glass rendering is AppKit and
/// OS-gated (exercised by hand); these pin the pure, portable
/// behavior — the gate, `hasBox`, round-trip, and command parse.
@Suite("Background style — Liquid Glass")
struct BackgroundStyleGlassTests {
    @Test("glassEnabled gates the finish on OS capability")
    func glassGate() {
        var style = AppBarLook()
        style.liquidGlass = false
        #expect(style.glassEnabled == false)
        style.liquidGlass = true
        // Effective only where the platform can render glass.
        #expect(style.glassEnabled == AppBarStyle.glassAvailable)
    }

    @Test("hasBox is the Boxed shape without the glass finish")
    func hasBox() {
        var style = AppBarLook()
        style.backgroundStyle = .boxed
        #expect(style.hasBox == !style.glassEnabled)
        style.backgroundStyle = .plain
        #expect(style.hasBox == false)
    }

    @Test("liquid_glass round-trips through JSON")
    func roundTrip() throws {
        var shelf = KiwiShelf()
        shelf.liquidGlass = false
        shelf.backgroundStyle = .boxed
        let data = try JSONEncoder().encode(shelf)
        let back = try JSONDecoder().decode(KiwiShelf.self, from: data)
        #expect(back.liquidGlass == false)
        #expect(back.backgroundStyle == .boxed)
    }

    @Test("the shelf parser takes liquid_glass; the bars' do not")
    func parseGlass() {
        let shelf = KiwiShelfCommandSetting.parse(
            field: "liquid_glass",
            args: [.bool(false)]
        )
        guard case .success(let setting) = shelf else {
            Issue.record("the shelf rejected liquid_glass")
            return
        }
        var value = KiwiShelf()
        setting.apply(to: &value)
        #expect(value.liquidGlass == false)
        #expect(
            (try? AppBarCommandSetting.parse(
                field: "liquid_glass",
                args: [.bool(true)]
            ).get()) == nil
        )
        #expect(
            (try? SpaceBarCommandSetting.parse(
                field: "liquid_glass",
                args: [.bool(true)]
            ).get()) == nil
        )
    }
}
