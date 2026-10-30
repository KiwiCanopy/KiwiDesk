import AppKit
import Testing

@testable import KiwiDeskCore

/// **The drag markers' fixed surfaces** (#2797): the drop zone an
/// untinted frosted plate — thinned glass, else the blur material,
/// else flat grey under Reduce transparency — with a light rim on
/// every one; the ghost a dark line inside a light halo with no
/// fill. Asserted on the views the overlay actually hosts.
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
    private static let radius: CGFloat = 8

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

    private static func white(_ color: CGColor?) -> CGFloat? {
        color.flatMap { NSColor(cgColor: $0) }?
            .usingColorSpace(.genericGray)?.whiteComponent
    }

    /// The rim every drop zone surface wears, over a clear ground.
    private static func expectRim(_ marker: DragOverlay.Marker) {
        let layer = marker.view.layer
        #expect(layer?.borderWidth == DragMarkerView.rimWidth)
        #expect((Self.white(layer?.borderColor) ?? 0) > 0.5)
        #expect(marker.view.line.isHidden && marker.view.halo.isHidden)
    }

    @Test("With glass the drop zone is untinted, thinned glass")
    func dropZoneIsUntintedGlass() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let overlay = DragOverlay()
        let dragged = Self.draggedWindow()
        defer {
            overlay.hideAll()
            dragged.orderOut(nil)
        }
        overlay.showDropZone(
            at: Self.slot,
            cornerRadius: Self.radius,
            glass: true,
            beneath: CGWindowID(dragged.windowNumber)
        )
        let marker = try #require(overlay.dropZone)
        let glass = try #require(marker.glass, "no glass hosted")
        #expect(!glass.isHidden)
        try #require(DragMarkerView.glassOpacity < 1)
        #expect(glass.alphaValue == DragMarkerView.glassOpacity)
        #expect(marker.tint.gradient?.colors == nil, "the glass is tinted")
        #expect(marker.view.material?.isHidden ?? true)
        #expect(marker.view.layer?.backgroundColor?.alpha == 0)
        Self.expectRim(marker)
    }

    @Test("Without glass the drop zone is the blur material")
    func dropZoneIsTheMaterial() throws {
        let overlay = DragOverlay()
        let dragged = Self.draggedWindow()
        defer {
            overlay.hideAll()
            dragged.orderOut(nil)
        }
        overlay.showDropZone(
            at: Self.slot,
            cornerRadius: Self.radius,
            glass: false,
            beneath: CGWindowID(dragged.windowNumber)
        )
        let marker = try #require(overlay.dropZone)
        let material = try #require(marker.view.material)
        #expect(!material.isHidden)
        #expect(material.alphaValue == DragMarkerView.glassOpacity)
        #expect(marker.glass?.isHidden ?? true)
        #expect(marker.view.layer?.backgroundColor?.alpha == 0)
        Self.expectRim(marker)
    }

    @Test("Under Reduce transparency the drop zone is flat grey")
    func dropZoneIsFlatGrey() throws {
        defer { LiquidGlassGate.override = { false } }
        LiquidGlassGate.override = { true }
        let overlay = DragOverlay()
        let dragged = Self.draggedWindow()
        defer {
            overlay.hideAll()
            dragged.orderOut(nil)
        }
        overlay.showDropZone(
            at: Self.slot,
            cornerRadius: Self.radius,
            glass: LiquidGlassGate.rendered(glass: true),
            beneath: CGWindowID(dragged.windowNumber)
        )
        let marker = try #require(overlay.dropZone)
        let ground = marker.view.layer?.backgroundColor
        #expect(ground?.alpha == DragMarkerView.flatColor.alphaComponent)
        #expect((ground?.alpha ?? 1) < 0.5, "an opaque drop zone")
        #expect(marker.view.material?.isHidden ?? true)
        #expect(marker.glass?.isHidden ?? true)
        Self.expectRim(marker)
    }

    @Test("The ghost is a dark line inside a light halo, unfilled")
    func ghostIsTwoTone() throws {
        let overlay = DragOverlay()
        let dragged = Self.draggedWindow()
        defer {
            overlay.hideAll()
            dragged.orderOut(nil)
        }
        overlay.showGhost(
            at: Self.slot,
            cornerRadius: Self.radius,
            beneath: CGWindowID(dragged.windowNumber)
        )
        let view = try #require(overlay.ghost?.view)
        #expect(!view.line.isHidden && !view.halo.isHidden)
        #expect(view.line.path != nil && view.line.path == view.halo.path)
        #expect(view.halo.lineWidth > view.line.lineWidth)
        let line = try #require(Self.white(view.line.strokeColor))
        let halo = try #require(Self.white(view.halo.strokeColor))
        #expect(line < 0.5 && halo > 0.5, "not dark inside light")
        #expect(view.line.fillColor == nil && view.halo.fillColor == nil)
        #expect(view.layer?.backgroundColor?.alpha == 0)
        #expect(view.layer?.borderWidth == 0)
        #expect(view.glass?.isHidden ?? true)
        #expect(view.material?.isHidden ?? true)
        // Inside the slot: the halo's outer edge meets the bounds.
        let box = try #require(view.halo.path?.boundingBox)
        #expect(box.minX == DragMarkerView.haloWidth / 2)
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
            overlay.showGhost(
                at: Self.slot,
                cornerRadius: Self.radius,
                beneath: id
            )
            overlay.showDropZone(
                at: Self.slot,
                cornerRadius: Self.radius,
                glass: false,
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
