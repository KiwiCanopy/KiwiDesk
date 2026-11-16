import AppKit
import Testing

@testable import KiwiDeskCore

/// `kiwishelf.handle_color` reaching an Auto bar's handle through
/// the real `updateBars()` (#3357, #3360): the core wears it at rest
/// and the progress fill at the fill strength, the hairline staying
/// neutral.
@Suite("Shelf handle colour wiring (#3357)", .serialized)
@MainActor
struct ShelfHandleColorWiringTests {
    private func handle(
        color: String,
        filling: Bool = false
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
        pinRevealLength()
        core.updateBars()
        let key = ShelfRevealer.Key(
            shelf: ShelfManager.Key(display: display.id, edge: .bottom),
            bar: .space
        )
        if filling {
            let start = Date(timeIntervalSince1970: 1_000)
            core.shelves.reveal.setFill(
                key,
                .init(
                    origin: 0.5,
                    started: start,
                    until: start.addingTimeInterval(10)
                )
            )
            core.updateBars()
        }
        return core.shelves.handles.handleForTesting(key)?.view
    }

    @Test(
        "A set colour paints the resting strip",
        .enabled(if: NSScreen.main != nil)
    )
    func setColourPaintsTheStrip() throws {
        let view = try #require(try handle(color: "#FF000080"))
        #expect(view.spec?.restHex == "#FF000080")
        #expect(view.spec?.fill == nil)
        let fill = try #require(view.core.layer?.backgroundColor)
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
        let fill = try #require(view.core.layer?.backgroundColor)
        var label: CGColor?
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            label =
                NSColor.labelColor
                .withAlphaComponent(ShelfHandleSpec.restStrength).cgColor
        }
        #expect(fill == label)
    }

    @Test(
        "The drawn fill uses fillColor, the hairline stays neutral",
        .enabled(if: NSScreen.main != nil)
    )
    func drawnFillUsesFillColor() throws {
        let view = try #require(try handle(color: "#FF000080", filling: true))
        #expect(view.spec?.fill != nil)
        #expect(!view.fillLayer.isHidden)
        let fill = try #require(view.fillLayer.backgroundColor)
        let rgb = try #require(
            NSColor(cgColor: fill)?.usingColorSpace(.sRGB)
        )
        #expect(abs(rgb.redComponent - 1) < 0.01)
        let full = 128.0 / 255 * ShelfHandleSpec.fillStrength
        #expect(abs(rgb.alphaComponent - full) < 0.01)
        // Red reads dark, so a white hairline, never its own colour.
        var expected: CGColor?
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            expected =
                ShelfHandleSpec.hairlineColor(hex: "#FF000080")
                .cgColor
        }
        let line = try #require(
            view.outline.layer?
                .backgroundColor
        )
        #expect(line == expected)
        #expect(line != fill)
    }
}
