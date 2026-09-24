import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The KiwiShelf card's App Bar switches name their layout by its
/// own key (#818, Family B), and every surface that reads the
/// label — the toggle, search, the unsaved-changes list — renders
/// the name rather than a bare specifier (#1517).
@Suite("KiwiShelf Show labels")
@MainActor
struct ShelfShowLabelTests {
    @Test("the census label and the control read one sentence")
    func labelsNameTheirLayout() {
        LocalizationManager.shared.select("en")
        let monocle = SettingsCensusLabel.label(
            for: .layoutAppBar(.monocleAppBarEnabled)
        )
        #expect(monocle == "App Bar in Monocle")
        #expect(SettingsCatalog.bars.monocleShowIn.text == monocle)
        let scrolling = SettingsCensusLabel.label(
            for: .layoutAppBar(.scrollingAppBarEnabled)
        )
        #expect(scrolling == "App Bar in Scrolling")
        #expect(SettingsCatalog.bars.scrollingShowIn.text == scrolling)
    }
}
