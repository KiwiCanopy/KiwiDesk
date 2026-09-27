import AppKit
import Testing

@testable import KiwiDeskCore

/// The painted sheen (#1644): a lightness ramp that keeps the
/// stroke's hue and alpha, whose only gate is its own value — it
/// is not glass (owner 2026-09-27).
@Suite("Border sheen ramp and leaf (#1644)")
@MainActor
struct BorderSheenTests {
    init() { LiquidGlassGate.override = { false } }

    private func hsl(_ color: NSColor) -> (CGFloat, CGFloat, CGFloat) {
        let c = color.usingColorSpace(.sRGB) ?? color
        return BorderStyle.rgbToHSL(
            r: c.redComponent,
            g: c.greenComponent,
            b: c.blueComponent
        )
    }

    @Test("the top lifts, the bottom shades, the hue and alpha stay")
    func rampMovesOnlyLightness() throws {
        // A colour the #578 cap does not bind, so both ends move
        // their full ruled amount.
        let hex = "#D9A521CC"
        let ramp = BorderSheen.colors(hex: hex)
        try #require(ramp.count == BorderSheen.locations.count)
        let (h, _, l) = hsl(NSColor(kiwiHex: hex))
        let (topH, _, topL) = hsl(ramp[0])
        let (bottomH, _, bottomL) = hsl(ramp[3])
        #expect(abs(topL - (l + (1 - l) * BorderSheen.lift)) < 0.01)
        #expect(abs(bottomL - l * BorderSheen.shade) < 0.01)
        #expect(abs(topH - h) < 1)
        #expect(abs(bottomH - h) < 1)
        for color in ramp {
            #expect(abs(color.alphaComponent - 0.8) < 0.01)
        }
    }

    /// Reduce transparency and the glass switch leave it alone: a
    /// bar look carries the leaf through the render gate untouched.
    @Test("the bar looks carry the leaf through the render gate")
    func looksCarryTheLeaf() {
        let before = LiquidGlassGate.override
        defer { LiquidGlassGate.override = before }
        var settings = TilingSettings()
        settings.kiwishelf.liquidGlass = false
        #expect(settings.spaceBarLook.sheen == settings.borderStyle.sheen)
        LiquidGlassGate.override = { true }
        #expect(LiquidGlassGate.rendered(settings.spaceBarLook).sheen)
        let app = settings.appBarGlobalLook
        #expect(LiquidGlassGate.rendered(app).sheen)
        settings.borderStyle.sheen = false
        #expect(!LiquidGlassGate.rendered(settings.spaceBarLook).sheen)
    }

    /// The focused ring's spec asks the leaf alone, through the
    /// real spec builder: glass stood down changes nothing, the
    /// leaf off takes it away, and the unfocused ring never wears it.
    @Test(
        "the focused ring wears the leaf, glass stood down or not",
        arguments: [true, false]
    )
    func ringAsksTheLeaf(_ leaf: Bool) {
        let before = LiquidGlassGate.override
        defer { LiquidGlassGate.override = before }
        LiquidGlassGate.override = { true }
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-sheen-\(UUID().uuidString)")
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        for id: UInt32 in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let focused = WindowID(1)
        let space = core.state.workspaces.space(of: focused)!
        core.state.workspaces.focus(focused, in: space)
        core.tiler.settings.kiwishelf.liquidGlass = false
        core.tiler.settings.borderStyle.unfocusedEnabled = true
        core.tiler.settings.borderStyle.sheen = leaf
        let specs = core.desiredBorderSpecs()
        #expect(specs.count == 2)
        for spec in specs {
            #expect(spec.sheen == (leaf && spec.window == focused))
        }
    }

    @Test("the ring's geometry carries the flag to both backends")
    func geometryCarriesSheen() {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        #expect(
            BorderGeometry.compute(
                windowFrame: frame,
                width: 4,
                cornerStyle: .rounded,
                sheen: true
            ).sheen
        )
        #expect(
            !BorderGeometry.compute(
                windowFrame: frame,
                width: 4,
                cornerStyle: .rounded
            ).sheen
        )
    }

    @Test("the leaf defaults on")
    func defaultsOn() {
        #expect(TilingSettings().borderStyle.sheen)
    }

    @Test("border.set_sheen writes the leaf, rejects non-bool")
    func setter() {
        let core = makeTestCore()
        #expect(
            core.execute("border.set_sheen", args: [.bool(false)])
                .isSuccess
        )
        #expect(!core.tiler.settings.borderStyle.sheen)
        #expect(
            !core.execute("border.set_sheen", args: [.string("x")])
                .isSuccess
        )
        #expect(!core.tiler.settings.borderStyle.sheen)
    }
}
