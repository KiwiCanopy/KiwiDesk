import AppKit
import Testing

@testable import KiwiDeskCore

/// **The drag markers' surfaces** (#3583): the drop zone a flat wash
/// and hairline of the focus border colour, with no glass; the ghost
/// the Space-switch plate without its icon — the shelf's Fill on
/// clear glass under "Tint KiwiHub and plates", untinted glass with
/// it off, the material under Reduce transparency. Asserted on the
/// views the overlay actually hosts.
@Suite("Drag marker surfaces", .serialized)
@MainActor
struct DragMarkerSurfaceTests {
    /// The machine's Reduce transparency setting is a default this
    /// fixture reasons from, so it is pinned off (#660, #1374).
    init() { LiquidGlassGate.override = { false } }

    /// Below macOS 26 nothing hosts glass.
    private static var drawsGlass: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    private static let slot = CGRect(x: 200, y: 200, width: 300, height: 200)
    private static let focus = "#564AB6"

    private static func look(
        tinted: Bool = true,
        fill: String = "#1A1A2EA5",
        focus: String = DragMarkerSurfaceTests.focus,
        glass: Bool = true
    ) -> DragMarkerLook {
        var shelf = KiwiShelf()
        shelf.fillColor = fill
        shelf.tintHubAndPlates = tinted
        return DragMarkerLook(
            cornerRadius: 8,
            focusColor: focus,
            shelf: shelf,
            storedGlass: glass
        )
    }

    /// A real window to stand in for the one being dragged: every
    /// marker is ordered directly beneath it.
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

    private static func rgb(_ color: CGColor?) -> [Int] {
        guard
            let color = color.flatMap({ NSColor(cgColor: $0) })?
                .usingColorSpace(.sRGB)
        else { return [] }
        return [color.redComponent, color.greenComponent, color.blueComponent]
            .map { Int(($0 * 255).rounded()) }
    }

    /// Runs `body` with a fresh overlay and a dragged window.
    private static func withOverlay(
        _ body: (DragOverlay, CGWindowID) throws -> Void
    ) rethrows {
        let overlay = DragOverlay()
        let dragged = draggedWindow()
        defer {
            overlay.hideAll()
            dragged.orderOut(nil)
        }
        try body(overlay, CGWindowID(dragged.windowNumber))
    }

    @Test("The drop zone is a wash and a hairline of the focus colour")
    func dropZoneIsAFocusWash() throws {
        try Self.withOverlay { overlay, id in
            overlay.showDropZone(at: Self.slot, look: Self.look(), beneath: id)
            let view = try #require(overlay.dropZone?.view)
            let layer = try #require(view.layer)
            let ink = Self.rgb(
                NSColor(kiwiHex: Self.focus).cgColor
            )
            #expect(Self.rgb(layer.backgroundColor) == ink)
            #expect(
                layer.backgroundColor?.alpha == DragMarkerView.washAlpha
            )
            #expect(layer.borderWidth == DragMarkerView.edgeWidth)
            #expect(Self.rgb(layer.borderColor) == ink)
            #expect(layer.borderColor?.alpha == DragMarkerView.edgeAlpha)
            #expect(view.plate == nil, "the drop zone hosts a plate")
            #expect(layer.cornerRadius == Self.look().cornerRadius)
            // A wash, never a plate: the window beneath stays seen.
            #expect(DragMarkerView.washAlpha < 0.5)
        }
    }

    /// The focus colour's own alpha is dropped, and a colourless one
    /// falls back to the system accent rather than drawing nothing.
    @Test("The drop zone sets its own alpha on any focus colour")
    func dropZoneOwnsItsAlpha() throws {
        try Self.withOverlay { overlay, id in
            for hex in ["#564AB680", "#564AB600", ""] {
                overlay.showDropZone(
                    at: Self.slot,
                    look: Self.look(focus: hex),
                    beneath: id
                )
                let layer = try #require(overlay.dropZone?.view.layer)
                #expect(
                    layer.backgroundColor?.alpha == DragMarkerView.washAlpha,
                    "\(hex)"
                )
                #expect(
                    layer.borderColor?.alpha == DragMarkerView.edgeAlpha,
                    "\(hex)"
                )
                // A colour with no alpha is no colour: the accent.
                if hex != "#564AB680" {
                    let accent = NSColor.controlAccentColor.cgColor
                    #expect(
                        Self.rgb(layer.backgroundColor)
                            == Self.rgb(accent),
                        "\(hex)"
                    )
                }
            }
        }
    }

    @Test("The drop zone keeps its wash under Reduce transparency")
    func dropZoneIgnoresTheGate() throws {
        defer { LiquidGlassGate.override = { false } }
        LiquidGlassGate.override = { true }
        try Self.withOverlay { overlay, id in
            overlay.showDropZone(at: Self.slot, look: Self.look(), beneath: id)
            let layer = try #require(overlay.dropZone?.view.layer)
            #expect(
                layer.backgroundColor?.alpha == DragMarkerView.washAlpha
            )
        }
    }

    @Test("Tinted, the ghost is the Fill on clear glass with the rim")
    func ghostWearsTheFill() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        try Self.withOverlay { overlay, id in
            // Untinted first, so the rim the tint turns on is seen
            // turning on rather than read off the panel's default.
            overlay.showGhost(
                at: Self.slot,
                look: Self.look(tinted: false),
                beneath: id
            )
            let untinted = try #require(
                overlay.ghost?.panel as? ActiveGlassPanel
            )
            #expect(!untinted.wearsActiveLook)
            overlay.showGhost(at: Self.slot, look: Self.look(), beneath: id)
            let marker = try #require(overlay.ghost)
            let plate = try #require(marker.plate)
            let glass = try #require(plate.glass, "no glass hosted")
            #expect(!plate.isHidden && !glass.isHidden)
            #expect(glass.alphaValue == 1, "the ghost's glass is thinned")
            #expect(plate.tint.gradient?.colors?.count == 2)
            #expect(plate.material == nil)
            if #available(macOS 26, *) {
                let style = (glass as? NSGlassEffectView)?.style
                #expect(style == .clear, "the tinted plate is regular")
            }
            let panel = try #require(marker.panel as? ActiveGlassPanel)
            #expect(panel.wearsActiveLook)
        }
    }

    @Test("Untinted, the ghost is untinted glass without the rim")
    func untintedGhostIsPlainGlass() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        try Self.withOverlay { overlay, id in
            // Tinted first: a plate the toggle leaves behind would
            // keep its Fill.
            overlay.showGhost(at: Self.slot, look: Self.look(), beneath: id)
            let tinted = try #require(overlay.ghost?.plate)
            overlay.showGhost(
                at: Self.slot,
                look: Self.look(tinted: false),
                beneath: id
            )
            let marker = try #require(overlay.ghost)
            let plate = try #require(marker.plate)
            #expect(plate !== tinted, "the tinted plate was kept")
            #expect(tinted.superview == nil)
            let glass = try #require(plate.glass)
            if #available(macOS 26, *) {
                let style = (glass as? NSGlassEffectView)?.style
                #expect(style == .regular, "the untinted plate is clear")
            }
            #expect(plate.tint.gradient?.colors == nil, "a tint drawn")
            let panel = try #require(marker.panel as? ActiveGlassPanel)
            #expect(!panel.wearsActiveLook)
        }
    }

    @Test("Under Reduce transparency the ghost is the Fill's material")
    func ghostStandsDownToTheMaterial() throws {
        defer { LiquidGlassGate.override = { false } }
        LiquidGlassGate.override = { true }
        try Self.withOverlay { overlay, id in
            overlay.showGhost(at: Self.slot, look: Self.look(), beneath: id)
            let first = try #require(overlay.ghost?.plate)
            overlay.showGhost(
                at: Self.slot,
                look: Self.look(fill: "#AA3355CC"),
                beneath: id
            )
            let plate = try #require(overlay.ghost?.plate)
            #expect(plate !== first, "a new Fill kept the old material")
            let material = try #require(plate.material)
            #expect(plate.glass == nil)
            let wash = try #require(FrostPlate.washColour(of: material))
            #expect(
                Self.rgb(wash.cgColor)
                    == Self.rgb(NSColor(kiwiHex: "#AA3355").cgColor)
            )
        }
    }

    @Test("With its glass leaf off the ghost is the material")
    func glassLeafOffIsTheMaterial() throws {
        try Self.withOverlay { overlay, id in
            overlay.showGhost(
                at: Self.slot,
                look: Self.look(glass: false),
                beneath: id
            )
            let plate = try #require(overlay.ghost?.plate)
            #expect(plate.material != nil)
            #expect(plate.glass == nil)
        }
    }

    @Test("A ghost drawn again on one ground keeps its plate")
    func sameGroundKeepsThePlate() throws {
        try Self.withOverlay { overlay, id in
            overlay.showGhost(at: Self.slot, look: Self.look(), beneath: id)
            let first = try #require(overlay.ghost?.plate)
            overlay.showGhost(at: Self.slot, look: Self.look(), beneath: id)
            #expect(overlay.ghost?.plate === first)
        }
    }

    /// Every marker sits BENEATH the dragged window at window
    /// level, glass or not — read off the window list, since a level
    /// alone is satisfied by a marker ordered in front at that level.
    @Test("Every marker stacks directly below the dragged window")
    func markersSitBelowTheDraggedWindow() throws {
        let overlay = DragOverlay()
        let dragged = Self.draggedWindow()
        defer {
            overlay.hideAll()
            dragged.orderOut(nil)
        }
        let id = CGWindowID(dragged.windowNumber)
        let show = {
            overlay.showGhost(at: Self.slot, look: Self.look(), beneath: id)
            overlay.showDropZone(
                at: Self.slot,
                look: Self.look(),
                beneath: id
            )
        }
        show()
        // Another window comes up over everything, then the dragged
        // one is raised past it — so the markers, left where they
        // were, would sit beneath `other`. The next show must
        // re-order them to directly beneath the dragged window.
        let other = Self.draggedWindow()
        defer { other.orderOut(nil) }
        dragged.orderFrontRegardless()
        show()
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
            #expect(at > draggedAt, "a marker is above the window")
            #expect(at < otherAt, "a marker stayed buried")
            #expect(panel.level == .normal)
        }
    }
}
