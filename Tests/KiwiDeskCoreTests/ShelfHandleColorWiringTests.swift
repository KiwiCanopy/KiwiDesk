import AppKit
import Testing

@testable import KiwiDeskCore

/// `kiwishelf.handle_color` reaching an Auto bar's resting strip
/// through the real `updateBars()` (#3357): the strip wears it at
/// rest, and the thickened plate keeps the Fill.
@Suite("Shelf handle colour wiring (#3357)", .serialized)
@MainActor
struct ShelfHandleColorWiringTests {
    private func handle(
        color: String
    ) throws -> ShelfHandleView? {
        let screen = try #require(NSScreen.screens.first)
        let display = try #require(screen.kiwiDisplay)
        let core = makeTestCore()
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.resolveSpaceDisplays(mainID: display.id)
        var settings = core.tiler.settings
        settings.spaceBarStyle.setEdge(.bottom)
        settings.appBarStyle.setEdge(.top)
        settings.spaceBarStyle.visibility = .auto
        settings.kiwishelf.handleColor = color
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        let key = ShelfManager.Key(display: display.id, edge: .bottom)
        return core.shelves.handles.handleForTesting(
            .init(shelf: key, bar: .space)
        )?.view
    }

    @Test(
        "A set colour paints the resting strip",
        .enabled(if: NSScreen.main != nil)
    )
    func setColourPaintsTheStrip() throws {
        let view = try #require(try handle(color: "#FF000080"))
        #expect(view.spec?.restHex == "#FF000080")
        #expect(view.spec?.hovered == false)
        let fill = try #require(view.plate.layer?.backgroundColor)
        let rgb = try #require(
            NSColor(cgColor: fill)?.usingColorSpace(.sRGB)
        )
        #expect(abs(rgb.redComponent - 1) < 0.01)
        #expect(rgb.greenComponent < 0.01)
        // Its own alpha times the rest strength (#3360 ruling 3).
        let rest = 128.0 / 255 * ShelfHandleSpec.restStrength
        #expect(abs(rgb.alphaComponent - rest) < 0.01)
    }

    @Test(
        "Automatic paints the label ink at the rest strength",
        .enabled(if: NSScreen.main != nil)
    )
    func automaticPaintsTheLabelInk() throws {
        let view = try #require(try handle(color: ""))
        #expect(view.spec?.restHex == "")
        let fill = try #require(view.plate.layer?.backgroundColor)
        var label: CGColor?
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            label =
                NSColor.labelColor
                .withAlphaComponent(ShelfHandleSpec.restStrength).cgColor
        }
        #expect(fill == label)
    }
}
