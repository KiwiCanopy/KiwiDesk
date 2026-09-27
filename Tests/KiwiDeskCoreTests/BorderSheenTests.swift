import AppKit
import Testing

@testable import KiwiDeskCore

/// The painted sheen (#1644): one signed strength. Positive
/// lightens the top toward white, negative darkens it toward black,
/// each by `BorderSheen.scale` × the strength; 0 draws none. Hue
/// and alpha stay the stroke's, the bottom keeps the colour, and
/// its only gate is its own value — it is not glass.
@Suite("Border sheen ramp and strength (#1644)")
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

    /// The top moves by scale × |s| of the room toward white or of
    /// the lightness toward black; the rest keeps the colour.
    @Test(
        "the top moves by scale times the strength, either way",
        arguments: [0.5, 1.0, -0.5, -1.0, 0.25]
    )
    func topMovesByStrength(_ strength: Double) throws {
        let hex = "#D9A521CC"
        let s = CGFloat(strength)
        let ramp = BorderSheen.colors(hex: hex, strength: s)
        try #require(ramp.count == BorderSheen.locations.count)
        let (h, _, l) = hsl(NSColor(kiwiHex: hex))
        let (topH, _, topL) = hsl(ramp[0])
        let (bottomH, _, bottomL) = hsl(try #require(ramp.last))
        let amount = abs(s) * BorderSheen.scale
        let expected = s > 0 ? l + (1 - l) * amount : l * (1 - amount)
        #expect(abs(topL - expected) < 0.01)
        #expect(s > 0 ? topL > l : topL < l)
        #expect(abs(bottomL - l) < 0.01)
        #expect(abs(topH - h) < 1)
        #expect(abs(bottomH - h) < 1)
        for color in ramp {
            #expect(abs(color.alphaComponent - 0.8) < 0.01)
        }
    }

    @Test("a strength of 0 keeps the colour at every stop")
    func zeroIsFlat() {
        let hex = "#D9A521"
        let base = NSColor(kiwiHex: hex)
        for color in BorderSheen.colors(hex: hex, strength: 0) {
            #expect(hsl(color) == hsl(base))
        }
    }

    @Test("the strength clamps into -1...1 and snaps a hair to 0")
    func clamps() {
        #expect(BorderStyle.clampSheen(3) == 1)
        #expect(BorderStyle.clampSheen(-3) == -1)
        #expect(BorderStyle.clampSheen(1e-12) == 0)
        #expect(BorderStyle.clampSheen(0.00004) == 0)
        #expect(BorderStyle.clampSheen(0.0001) == 0.0001)
        #expect(BorderStyle.clampSheen(-0.35) == -0.35)
    }

    /// Reduce transparency and the glass switch leave it alone: a
    /// bar look carries the strength through the render gate.
    @Test("the bar looks carry the strength through the render gate")
    func looksCarryTheStrength() {
        let before = LiquidGlassGate.override
        defer { LiquidGlassGate.override = before }
        var settings = TilingSettings()
        settings.kiwishelf.liquidGlass = false
        settings.borderStyle.sheen = -0.4
        LiquidGlassGate.override = { true }
        #expect(LiquidGlassGate.rendered(settings.spaceBarLook).sheen == -0.4)
        let app = settings.appBarGlobalLook
        #expect(LiquidGlassGate.rendered(app).sheen == -0.4)
    }

    /// The focused ring's spec asks the strength alone, through the
    /// real spec builder: glass stood down changes nothing, and the
    /// unfocused ring never wears it.
    @Test(
        "the focused ring wears the strength, glass stood down or not",
        arguments: [0.5, -0.5, 0.0]
    )
    func ringAsksTheStrength(_ strength: Double) {
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
        core.tiler.settings.borderStyle.sheen = CGFloat(strength)
        let specs = core.desiredBorderSpecs()
        #expect(specs.count == 2)
        for spec in specs {
            #expect(
                spec.sheen
                    == (spec.window == focused ? CGFloat(strength) : 0)
            )
        }
    }

    @Test("the ring's geometry carries the strength to both backends")
    func geometryCarriesSheen() {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        #expect(
            BorderGeometry.compute(
                windowFrame: frame,
                width: 4,
                cornerStyle: .rounded,
                sheen: -0.5
            ).sheen == -0.5
        )
        #expect(
            BorderGeometry.compute(
                windowFrame: frame,
                width: 4,
                cornerStyle: .rounded
            ).sheen == 0
        )
    }

    @Test("the strength defaults to a half lift")
    func defaultsToHalf() {
        #expect(TilingSettings().borderStyle.sheen == 0.5)
    }

    @Test("border.set_sheen writes a clamped number, rejects a non-number")
    func setter() {
        let core = makeTestCore()
        #expect(
            core.execute("border.set_sheen", args: [.number(-0.3)])
                .isSuccess
        )
        #expect(core.tiler.settings.borderStyle.sheen == -0.3)
        #expect(
            core.execute("border.set_sheen", args: [.number(4)])
                .isSuccess
        )
        #expect(core.tiler.settings.borderStyle.sheen == 1)
        #expect(
            !core.execute("border.set_sheen", args: [.bool(true)])
                .isSuccess
        )
        #expect(core.tiler.settings.borderStyle.sheen == 1)
    }
}
