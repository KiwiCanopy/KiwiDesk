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
}
