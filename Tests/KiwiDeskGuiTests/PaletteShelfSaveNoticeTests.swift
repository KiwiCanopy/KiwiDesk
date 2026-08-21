import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// In the Palette save popover, saving a palette whose colors
/// match an existing built-in or user palette informs the user
/// while keeping Save enabled (#844).
@Suite("Palette shelf save notice (#844)", .serialized)
@MainActor
struct PaletteShelfSaveNoticeTests {
    private func makeShelf() -> (SettingsModel, PaletteShelf) {
        LocalizationManager.shared.select("en")
        let model = makeTestModel()
        let shelf = PaletteShelf(model: model)
        return (model, shelf)
    }

    @Test("Reserved built-in name produces reserved notice and blocks save")
    func reservedBuiltinNotice() {
        let (_, shelf) = makeShelf()
        #expect(
            shelf.saveNotice(PaletteCatalog.neonName)
                == "That name is a built-in palette — choose another."
        )
        #expect(!shelf.canSave(PaletteCatalog.neonName))
    }

    @Test("Colors matching built-in palette produce already-saved notice")
    func matchingBuiltinNotice() {
        let (_, shelf) = makeShelf()
        // Fresh model has default colors matching "Kiwi (Default)".
        #expect(
            shelf.saveNotice("My New Palette")
                == "These colors are already saved as “Kiwi (Default)”."
        )
        #expect(shelf.canSave("My New Palette"))
    }

    @Test("Unique colors produce no notice and permit save")
    func uniqueColorsProduceNoNotice() {
        let (model, shelf) = makeShelf()
        model.config.settings.borderStyle.focusedColor = "#123456"
        model.config.settings.borderStyle.unfocusedColor = "#654321"
        #expect(shelf.saveNotice("Unique Theme") == nil)
        #expect(shelf.canSave("Unique Theme"))
    }

    @Test("Colors matching saved user palette produce already-saved notice")
    func matchingUserPaletteNotice() {
        let (model, shelf) = makeShelf()
        model.config.settings.borderStyle.focusedColor = "#123456"
        let customColors = ColorPaletteKeys.extract(
            from: model.config.settings
        )
        try? shelf.store.save(
            ColorPalette(name: "Studio Dark", colors: customColors)
        )
        #expect(
            shelf.saveNotice("Studio Copy")
                == "These colors are already saved as “Studio Dark”."
        )
        #expect(shelf.canSave("Studio Copy"))
    }
}
