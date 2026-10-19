import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The bars' show/hide shortcut rows (#761): a row greys only
/// while its bar is `always` wherever it can show, and its reason
/// is a live pointer to KiwiShelf & Bars.
@Suite("KiwiShelf shortcut rows (#761)")
struct KiwiShelfShortcutsGroupTests {
    @Test("each row's caption places its link")
    @MainActor
    func captionsPlaceTheirLink() {
        LocalizationManager.shared.select("en")
        let slot = CrossReferenceRow.linkSlot
        for key in [
            SettingKey.shortcuts(.toggleSpaceBar), .shortcuts(.toggleAppBar),
        ] {
            #expect(KiwiShelfShortcutsGroup.caption(key).contains(slot))
        }
    }

    @Test("a row greys only while its bar is always everywhere")
    func inertFollowsTheBars() {
        var settings = TilingSettings()
        settings.spaceBarStyle.visibility = .always
        settings.monocle.appBar.visibility = .always
        settings.scrolling.appBar.visibility = .always
        let space = SettingKey.shortcuts(.toggleSpaceBar)
        let app = SettingKey.shortcuts(.toggleAppBar)
        #expect(KiwiShelfShortcutsGroup.inert(space, settings))
        #expect(KiwiShelfShortcutsGroup.inert(app, settings))
        settings.spaceBarStyle.visibility = .hidden
        settings.scrolling.appBar.visibility = .auto
        #expect(!KiwiShelfShortcutsGroup.inert(space, settings))
        #expect(!KiwiShelfShortcutsGroup.inert(app, settings))
    }
}
