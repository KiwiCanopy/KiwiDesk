import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Option C's rules (#1684, owner 2026-09-27): after a click the
/// colors row offers the look's palette back only while that choice
/// still stands, and a second click never loses the first undo.
@Suite("Look colors offer")
struct LookColorsOfferTests {
    private let slate = PaletteCatalog.bundled().first {
        $0.name == "Slate"
    }!
    private var taskbar: ShelfLook {
        LookCatalog.bundled(sizes: []).first { $0.name == "Taskbar" }!
    }

    /// The draft after clicking Taskbar over the shipped colours.
    private func clicked() -> (TilingSettings, [String: String]) {
        var settings = TilingSettings()
        let before = ColorPaletteKeys.extract(from: settings)
        taskbar.apply(to: &settings, palette: slate)
        return (settings, before)
    }

    @Test("a click offers the tick, and unticking restores")
    func offersAndRestores() throws {
        let (settings, before) = clicked()
        let offer = LookColorsOffer.decide(
            look: taskbar,
            before: before,
            palette: slate,
            settings: settings
        )
        guard case .tick(let palette, let prior) = offer else {
            Issue.record("no tick offered")
            return
        }
        #expect(palette == slate)
        var unticked = settings
        prior.apply(to: &unticked)
        #expect(
            ColorPaletteKeys.extract(from: unticked) == before
        )
        // Unticked, the row stays so the colors can come back.
        #expect(
            LookColorsOffer.decide(
                look: taskbar,
                before: before,
                palette: slate,
                settings: unticked
            ) == .tick(palette: slate, before: prior)
        )
    }

    @Test("no offer once the styling is superseded")
    func supersededStyling() {
        var (settings, before) = clicked()
        settings.kiwishelf.thickness = 30
        #expect(
            LookColorsOffer.decide(
                look: taskbar,
                before: before,
                palette: slate,
                settings: settings
            ) == nil
        )
    }

    @Test("no offer once the colors are the user's own")
    func supersededColors() {
        var (settings, before) = clicked()
        settings.kiwishelf.fillColor = "#123456"
        #expect(
            LookColorsOffer.decide(
                look: taskbar,
                before: before,
                palette: slate,
                settings: settings
            ) == nil
        )
    }

    @Test("no offer when the palette was already live")
    func alreadyLive() {
        var settings = TilingSettings()
        slate.apply(to: &settings)
        let before = ColorPaletteKeys.extract(from: settings)
        taskbar.apply(to: &settings, palette: slate)
        #expect(
            LookColorsOffer.decide(
                look: taskbar,
                before: before,
                palette: slate,
                settings: settings
            ) == nil
        )
    }

    @Test("a missing palette is named")
    func paletteGone() {
        let (settings, before) = clicked()
        #expect(
            LookColorsOffer.decide(
                look: taskbar,
                before: before,
                palette: nil,
                settings: settings
            ) == .paletteGone("Slate")
        )
    }

    @Test("a second click keeps the first click's colors")
    func reclickKeepsUndo() {
        let (settings, before) = clicked()
        let kept = LookColorsOffer.before(
            clicking: (taskbar, before),
            previousPalette: slate,
            settings: settings
        )
        #expect(kept == before)
        var edited = settings
        edited.kiwishelf.fillColor = "#123456"
        #expect(
            LookColorsOffer.before(
                clicking: (taskbar, before),
                previousPalette: slate,
                settings: edited
            ) == ColorPaletteKeys.extract(from: edited)
        )
    }
}
