import AppKit
import Testing

@testable import KiwiDeskCore

/// **The sticky mark as tinted glass** (#1621): it takes its own
/// colour through `GlassTint`, fading downward, and falls back to
/// today's flat look with the finish off. Asserted on the views the
/// overlay actually hosts, not on the tint arithmetic, which
/// `GlassTintCapTests` owns. The drag markers' surfaces are
/// `DragMarkerSurfaceTests`'.
@Suite("Liquid Glass sticky mark", .serialized)
@MainActor
struct OverlayGlassTests {
    /// The machine's Reduce transparency setting is a default this
    /// fixture reasons from, so it is pinned off (#660, #1374).
    init() { LiquidGlassGate.override = { false } }

    /// Below macOS 26 nothing hosts glass, so every clause would
    /// pass on a nil glass view.
    private static var drawsGlass: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    /// The colour is the symbol's on glass and off it (#2831): the
    /// glass stays clear, and no disc comes back on the flat finish.
    @Test("The sticky mark turns untinted glass and back")
    func stickyMarkTogglesGlass() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let plate = StickyMarkPlate()
        plate.setMarkColor("#E0892BB3")
        plate.setGlass(true)
        let glass = try #require(plate.glass, "no glass hosted")
        #expect(plate.hud.isHidden)
        #expect(!glass.isHidden)
        #expect(
            plate.content.isDescendant(of: glass),
            "glyphs not in glass"
        )
        #expect(
            plate.tint.gradient?.colors == nil,
            "the colour tinted the glass"
        )
        let ink = try #require(plate.symbol.contentTintColor)
        #expect(ink == NSColor(kiwiHex: "#E0892BB3"))
        plate.setGlass(false)
        #expect(!plate.hud.isHidden)
        #expect(glass.isHidden)
        #expect(plate.tint.isHiddenOrHasHiddenAncestor)
        #expect(plate.content.superview === plate)
        #expect(plate.symbol.contentTintColor == ink)
    }

    /// No colour is clear glass, not a tint of the empty string.
    @Test("A sticky mark with no colour is untinted glass")
    func uncolouredMarkIsClearGlass() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let plate = StickyMarkPlate()
        plate.setMarkColor("")
        plate.setGlass(true)
        #expect(plate.glass?.isHidden == false)
        #expect(plate.tint.gradient?.colors == nil)
    }

    @Test("Reduce transparency stands the overlays' glass down")
    func gateStandsDown() {
        defer { LiquidGlassGate.override = { false } }
        LiquidGlassGate.override = { true }
        #expect(!LiquidGlassGate.rendered(glass: true))
        #expect(!LiquidGlassGate.rendered(glass: false))
        LiquidGlassGate.override = { false }
        #expect(LiquidGlassGate.rendered(glass: true) == Self.drawsGlass)
    }

    @Test("The Lua setters write their leaves")
    func luaSettersWrite() {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-glass-\(UUID().uuidString)")
        )
        for on in [false, true] {
            core.execute("drag.set_liquid_glass", args: [.bool(on)])
            core.execute("sticky.set_liquid_glass", args: [.bool(on)])
            #expect(core.tiler.settings.dragLiquidGlass == on)
            #expect(core.tiler.settings.stickyStyle.liquidGlass == on)
        }
    }
}
