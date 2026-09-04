import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The pushed per-space override editor's navigation state (#678
/// 8b). The editor is a view-state branch driven by
/// `SettingsNavigation.spaceOverridesFocus`, so the invariant that
/// matters is that outside code can drop it back to the list:
/// opening the window and switching edit target both call
/// `resetSurfaces`, which must clear the focus or the window would
/// re-open onto a stale per-space editor.
struct SpaceOverridesNavTests {
    @Test("resetSurfaces drops the pushed override editor")
    func resetClearsOverrideFocus() {
        var nav = SettingsNavigation()
        nav.spaceOverridesFocus = SpaceID("code")
        // Pinned alongside the surfaces it sits beside. The
        // REGISTER — that no per-visit field is forgotten — is
        // `SettingsNavigationResetTests`' by reflection since
        // #1127; these two stay because this suite's subject is
        // the pushed editor and they are what it opens beside.
        nav.layoutModeTab = .stack
        nav.shortcutsLayer = "media"
        nav.resetSurfaces()
        #expect(nav.spaceOverridesFocus == nil)
        #expect(nav.layoutModeTab == nil)
        #expect(nav.shortcutsLayer == nil)
    }
}
