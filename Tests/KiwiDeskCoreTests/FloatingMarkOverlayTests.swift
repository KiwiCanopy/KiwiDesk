import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The floating mark as DRAWN (#1799): the overlay fits its slots
/// to the window through the manager's own sync, the plate paints
/// each slot's colour, and a marked window joins the WindowServer
/// watch set with no ring — `FloatingMarkTests` holds the specs.
@Suite("Floating mark overlay", .serialized)
@MainActor
struct FloatingMarkOverlayTests {
    private func spec(
        width: CGFloat,
        _ glyphs: [StickyMarkManager.Glyph]
    ) -> StickyMarkManager.Spec {
        StickyMarkManager.Spec(
            window: WindowID(1),
            frame: CGRect(x: 0, y: 0, width: width, height: 300),
            glyphs: glyphs,
            glass: false
        )
    }

    private func overlay(
        _ manager: StickyMarkManager
    ) throws -> StickyMarkOverlay {
        try #require(manager.overlays[WindowID(1)])
    }

    @Test("A wide window draws both glyphs, a narrow one the outer")
    func slotsFitTheWindow() throws {
        let manager = StickyMarkManager()
        manager.sync([spec(width: 400, [.sticky(), .floating()])])
        let wide = try overlay(manager)
        #expect(wide.plate.slotCount == 2)
        #expect(!wide.plate.innerSymbol.isHidden)
        #expect(wide.currentWidth == StickyMarkPlate.size * 2)
        manager.sync([spec(width: 100, [.sticky(), .floating()])])
        #expect(wide.plate.slotCount == 1)
        #expect(wide.plate.innerSymbol.isHidden)
        #expect(wide.currentWidth == StickyMarkPlate.size)
    }

    @Test("A glyph joining a live plate is drawn on the next sync")
    func glyphJoinsLivePlate() throws {
        let manager = StickyMarkManager()
        manager.sync([spec(width: 400, [.sticky()])])
        let live = try overlay(manager)
        #expect(live.plate.slotCount == 1)
        manager.sync([spec(width: 400, [.sticky(), .floating()])])
        #expect(try overlay(manager) === live)
        #expect(live.plate.slotCount == 2)
        #expect(!live.plate.innerSymbol.isHidden)
        manager.sync([spec(width: 400, [.floating()])])
        #expect(live.plate.slotCount == 1)
        #expect(!live.isSticky)
    }

    @Test("A spec orders its glyphs sticky first, whatever it is handed")
    func specOrdersGlyphs() {
        let spec = spec(width: 400, [.floating(), .sticky()])
        #expect(spec.glyphs.map(\.kind) == [.sticky, .floating])
    }

    @Test("Each slot paints its own disc on the flat finish")
    func flatSlotColours() {
        let plate = StickyMarkPlate()
        let image = NSImage(
            systemSymbolName: FloatingStyle.symbolName,
            accessibilityDescription: nil
        )
        plate.setMarkColor("#FF0000")
        plate.setInner(image, hex: "#00FF00")
        #expect(!plate.roundel.isHidden)
        #expect(!plate.innerRoundel.isHidden)
        #expect(
            plate.innerRoundel.layer?.backgroundColor
                == NSColor(kiwiHex: "#00FF00").cgColor
        )
        plate.setInner(image, hex: "")
        #expect(plate.innerRoundel.isHidden)
        #expect(!plate.roundel.isHidden)
        plate.setInner(nil, hex: "#00FF00")
        #expect(plate.innerRoundel.isHidden)
    }

    @Test("Glass drops both discs and tints with the outer colour")
    func glassTintsWithTheOuterColour() throws {
        let plate = StickyMarkPlate()
        plate.setInner(
            NSImage(
                systemSymbolName: FloatingStyle.symbolName,
                accessibilityDescription: nil
            ),
            hex: "#00FF00"
        )
        plate.setMarkColor("#FF0000")
        plate.setGlass(true)
        try #require(plate.glass != nil, "no glass hosted")
        #expect(plate.roundel.isHidden)
        #expect(plate.innerRoundel.isHidden)
        #expect(plate.markHex == "#FF0000")
        #expect(!plate.tint.isHidden)
    }

    @Test("A floating-only mark joins the watch set with no ring")
    func floatingMarkIsTracked() {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-float-track-\(UUID().uuidString)"
                )
        )
        core.tiler.settings.borderStyle.enabled = false
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(1), pid: 1, appName: "A")
            )
        )
        core.state.setFloating(WindowID(1), true)
        core.updateStickyMarks()
        #expect(core.borders.markTracked == [WindowID(1)])
        #expect(core.stickyMarks.markedWindows == [WindowID(1)])
    }
}
