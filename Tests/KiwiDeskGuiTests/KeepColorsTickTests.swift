import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The "Keep previous colors" tick's write through the real model
/// (#1752): it answers whether it left the draft clean, which is
/// what `KeepColorsOffer.afterDraftCleaned` reads — so the premise
/// that `isDirty` is recomputed on the write is held here, beside
/// the pure decision `KeepColorsOfferTests` holds.
@Suite("Keep previous colors tick")
@MainActor
struct KeepColorsTickTests {
    private func recoloured(_ settings: TilingSettings) -> ShelfLook {
        var other = settings
        other.kiwishelf.fillColor = "#0A0B0C"
        return ShelfLook(
            name: "Same shape",
            style: LookKeys.extract(from: settings),
            colors: ColorPaletteKeys.extract(from: other)
        )
    }

    @Test("a tick back to the saved colours leaves the draft clean")
    func tickCleansTheDraft() {
        let model = makeTestModel()
        #expect(!model.isDirty)
        let saved = ColorPaletteKeys.extract(from: model.config.settings)
        model.applyLook(recoloured(model.config.settings))
        #expect(model.isDirty)
        #expect(model.paintColors(saved))
        #expect(!model.isDirty)
    }

    @Test("a tick that leaves the shape changed reports it dirty")
    func tickUnderAnotherShapeStaysDirty() throws {
        let model = makeTestModel()
        let saved = ColorPaletteKeys.extract(from: model.config.settings)
        let taskbar = try #require(
            LookCatalog.bundled(sizes: []).first { $0.name == "Taskbar" }
        )
        model.applyLook(taskbar)
        #expect(!model.paintColors(saved))
        #expect(model.isDirty)
    }
}
