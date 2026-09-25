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

    /// A real window to stand in for the one being dragged: glass
    /// markers exist only beneath one.
    private static func draggedWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: slot,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.orderFrontRegardless()
        return window
    }

    @Test("Both drag markers are glass tinted by their fill, fading down")
    func markersAreTintedGlass() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let overlay = DragOverlay()
        let dragged = Self.draggedWindow()
        defer {
            overlay.hideAll()
            dragged.orderOut(nil)
        }
        let id = CGWindowID(dragged.windowNumber)
        let style = DragVisual.ghostDefault
        overlay.showGhost(
            at: Self.slot,
            style: style,
            cornerRadius: 8,
            glassBeneath: id
        )
        overlay.showDropZone(
            at: Self.slot,
            style: DragVisual.dropZoneDefault,
            cornerRadius: 8,
            glassBeneath: id
        )
        for marker in [overlay.ghost, overlay.dropZone] {
            let marker = try #require(marker)
            let glass = try #require(marker.glass, "no glass hosted")
            #expect(!glass.isHidden)
            #expect(!marker.tint.isHidden, "the fill drew no tint")
            #expect(marker.tint.gradient?.startPoint == Self.top)
            // The border stays on the container, above the glass.
            let layer = try #require(marker.panel.contentView?.layer)
            let width = style.border ? style.borderWidth : 0
            #expect(layer.borderWidth == width)
            #expect(layer.backgroundColor?.alpha == 0)
        }
    }

    @Test("With the finish off a marker is flat again")
    func finishOffIsFlat() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let overlay = DragOverlay()
        let dragged = Self.draggedWindow()
        defer {
            overlay.hideAll()
            dragged.orderOut(nil)
        }
        var style = DragVisual.ghostDefault
        style.fill = true
        overlay.showGhost(
            at: Self.slot,
            style: style,
            cornerRadius: 8,
            glassBeneath: CGWindowID(dragged.windowNumber)
        )
        overlay.showGhost(
            at: Self.slot,
            style: style,
            cornerRadius: 8,
            glassBeneath: nil
        )
        let marker = try #require(overlay.ghost)
        #expect(marker.glass?.isHidden == true)
        #expect(marker.tint.isHidden)
        let fill = try #require(DragVisual.parseHex(style.fillColor))
        let alpha = marker.panel.contentView?.layer?.backgroundColor?.alpha
        #expect(abs((alpha ?? -1) - fill.alpha) < 0.01)
    }

    /// Under glass both markers sit BENEATH the dragged window in
    /// the actual stacking, so their glass never blurs the window
    /// in hand — read off the window list, since a level alone is
    /// satisfied by a marker ordered in front at that level.
    @Test("Glass markers stack below the dragged window; flat ones float")
    func glassMarkersSitBelowTheDraggedWindow() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let overlay = DragOverlay()
        let dragged = Self.draggedWindow()
        defer {
            overlay.hideAll()
            dragged.orderOut(nil)
        }
        let id = CGWindowID(dragged.windowNumber)
        overlay.showGhost(
            at: Self.slot,
            style: .ghostDefault,
            cornerRadius: 8,
            glassBeneath: id
        )
        overlay.showDropZone(
            at: Self.slot,
            style: .dropZoneDefault,
            cornerRadius: 8,
            glassBeneath: id
        )
        // Another window comes up over everything, then the dragged
        // one is raised past it — so the markers, left where they
        // were, would sit beneath `other`. The next show must
        // re-order them to directly beneath the dragged window.
        let other = Self.draggedWindow()
        defer { other.orderOut(nil) }
        dragged.orderFrontRegardless()
        overlay.showGhost(
            at: Self.slot,
            style: .ghostDefault,
            cornerRadius: 8,
            glassBeneath: id
        )
        overlay.showDropZone(
            at: Self.slot,
            style: .dropZoneDefault,
            cornerRadius: 8,
            glassBeneath: id
        )
        let order = NSWindow.windowNumbers(options: []) ?? []
        let draggedAt = try #require(
            order.firstIndex(of: NSNumber(value: dragged.windowNumber))
        )
        let otherAt = try #require(
            order.firstIndex(of: NSNumber(value: other.windowNumber))
        )
        for marker in [overlay.ghost, overlay.dropZone] {
            let panel = try #require(marker?.panel)
            let at = try #require(
                order.firstIndex(of: NSNumber(value: panel.windowNumber))
            )
            #expect(at > draggedAt, "a glass marker is above the window")
            #expect(at < otherAt, "a glass marker stayed buried")
            #expect(panel.level == .normal)
        }
        overlay.showGhost(
            at: Self.slot,
            style: .ghostDefault,
            cornerRadius: 8,
            glassBeneath: nil
        )
        #expect(overlay.ghost?.panel.level == .floating)
    }

    /// The drop zone's glass is thinned and the ghost's is not;
    /// the shape, not the number (#1021).
    @Test("Only the drop zone's glass is thinned")
    func dropZoneGlassIsThinned() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let overlay = DragOverlay()
        let dragged = Self.draggedWindow()
        defer {
            overlay.hideAll()
            dragged.orderOut(nil)
        }
        let id = CGWindowID(dragged.windowNumber)
        overlay.showGhost(
            at: Self.slot,
            style: .ghostDefault,
            cornerRadius: 8,
            glassBeneath: id
        )
        overlay.showDropZone(
            at: Self.slot,
            style: .dropZoneDefault,
            cornerRadius: 8,
            glassBeneath: id
        )
        try #require(DragOverlay.dropZoneGlassOpacity < 1)
        #expect(overlay.ghost?.glass?.alphaValue == 1)
        #expect(
            overlay.dropZone?.glass?.alphaValue
                == DragOverlay.dropZoneGlassOpacity
        )
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
        #expect(
            plate.content.isDescendant(of: glass),
            "glyphs not in glass"
        )
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
