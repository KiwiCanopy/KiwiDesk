import AppKit
import Testing

@testable import KiwiDeskCore

/// **The drag markers and the sticky mark as tinted glass**
/// (#1620, #1621): each takes its own colour through `GlassTint`,
/// fading downward, and falls back to today's flat look with the
/// finish off. Asserted on the views the overlays actually host,
/// not on the tint arithmetic, which `GlassTintCapTests` owns.
@Suite("Liquid Glass drag markers and sticky mark", .serialized)
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

    /// Downward: the anchor at the top of the unit square.
    private static let top = CGPoint(x: 0.5, y: 1)

    private static let slot = CGRect(x: 200, y: 200, width: 300, height: 200)

    @Test("Both drag markers are glass tinted by their fill, fading down")
    func markersAreTintedGlass() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let overlay = DragOverlay()
        defer { overlay.hideAll() }
        let style = DragVisual.ghostDefault
        overlay.showGhost(
            at: Self.slot,
            style: style,
            cornerRadius: 8,
            glass: true
        )
        overlay.showDropZone(
            at: Self.slot,
            style: DragVisual.dropZoneDefault,
            cornerRadius: 8,
            glass: true
        )
        for marker in [overlay.ghost, overlay.dropZone] {
            let marker = try #require(marker)
            let glass = try #require(marker.glass, "no glass hosted")
            #expect(!glass.isHidden)
            #expect(!marker.tint.isHidden, "the fill drew no tint")
            #expect(marker.tint.gradient?.startPoint == Self.top)
            // The border stays on the container, above the glass.
            let layer = try #require(marker.panel.contentView?.layer)
            #expect(
                layer.borderWidth == (style.border ? style.borderWidth : 0)
            )
            #expect(layer.backgroundColor?.alpha == 0)
        }
    }

    @Test("With the finish off a marker is flat again")
    func finishOffIsFlat() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let overlay = DragOverlay()
        defer { overlay.hideAll() }
        var style = DragVisual.ghostDefault
        style.fill = true
        overlay.showGhost(
            at: Self.slot,
            style: style,
            cornerRadius: 8,
            glass: true
        )
        overlay.showGhost(
            at: Self.slot,
            style: style,
            cornerRadius: 8,
            glass: false
        )
        let marker = try #require(overlay.ghost)
        #expect(marker.glass?.isHidden == true)
        #expect(marker.tint.isHidden)
        let fill = try #require(DragVisual.parseHex(style.fillColor))
        let alpha = marker.panel.contentView?.layer?.backgroundColor?.alpha
        #expect(abs((alpha ?? -1) - fill.alpha) < 0.01)
    }

    /// Under glass both markers sit at the dragged window's level,
    /// directly beneath it, so their glass never blurs the window
    /// in hand; flat, they float above everything as before.
    @Test("Glass markers drop below the dragged window; flat ones float")
    func glassMarkersSitBelowTheDraggedWindow() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let overlay = DragOverlay()
        defer { overlay.hideAll() }
        let dragged = NSWindow(
            contentRect: Self.slot,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        dragged.orderFrontRegardless()
        defer { dragged.orderOut(nil) }
        let id = CGWindowID(dragged.windowNumber)
        overlay.showGhost(
            at: Self.slot,
            style: .ghostDefault,
            cornerRadius: 8,
            glass: true,
            below: id
        )
        overlay.showDropZone(
            at: Self.slot,
            style: .dropZoneDefault,
            cornerRadius: 8,
            glass: true,
            below: id
        )
        #expect(overlay.ghost?.panel.level == .normal)
        #expect(overlay.dropZone?.panel.level == .normal)
        overlay.showGhost(
            at: Self.slot,
            style: .ghostDefault,
            cornerRadius: 8,
            glass: false,
            below: id
        )
        #expect(overlay.ghost?.panel.level == .floating)
    }

    @Test("The sticky mark turns tinted glass and back")
    func stickyMarkTogglesGlass() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let plate = StickyMarkPlate()
        plate.setMarkColor("#E0892BB3")
        plate.setGlass(true)
        let glass = try #require(plate.glass, "no glass hosted")
        #expect(plate.hud.isHidden)
        #expect(!glass.isHidden)
        #expect(plate.content.superview !== plate, "glyphs not in glass")
        #expect(plate.roundel.isHidden, "the disc stayed on glass")
        #expect(!plate.tint.isHidden)
        #expect(plate.tint.gradient?.startPoint == Self.top)
        plate.setGlass(false)
        #expect(!plate.hud.isHidden)
        #expect(glass.isHidden)
        #expect(plate.tint.isHidden)
        #expect(plate.content.superview === plate)
        #expect(!plate.roundel.isHidden, "the disc did not come back")
    }

    /// No colour is clear glass, not a tint of the empty string.
    @Test("A sticky mark with no colour is clear glass")
    func uncolouredMarkIsClearGlass() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let plate = StickyMarkPlate()
        plate.setMarkColor("")
        plate.setGlass(true)
        #expect(plate.glass?.isHidden == false)
        #expect(plate.tint.isHidden)
    }

    @Test("Reduce transparency stands the overlays' glass down")
    func gateStandsDown() {
        LiquidGlassGate.override = { true }
        defer { LiquidGlassGate.override = { false } }
        #expect(!LiquidGlassGate.rendered(glass: true))
        #expect(!LiquidGlassGate.rendered(glass: false))
        LiquidGlassGate.override = { false }
        #expect(LiquidGlassGate.rendered(glass: true) == Self.drawsGlass)
    }

    @Test("The Lua setters write their leaves")
    func luaSettersWrite() {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
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
