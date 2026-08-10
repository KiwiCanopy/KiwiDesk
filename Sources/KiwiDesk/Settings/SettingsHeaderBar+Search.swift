import KiwiDeskCore

/// The header bar's search context (#678 turn 11) — its own
/// file for the §2.1 ceiling, not for reuse.
extension SettingsHeaderBar {
    /// Everything search may consult, collected here from state
    /// already in memory (spec 11a: nothing on the search path
    /// touches AX, the session or the filesystem). Palette names
    /// are deliberately absent for now: `PaletteStore` is
    /// stateless and file-backed by design, so listing them here
    /// would put a disk read on every keystroke — the Places
    /// group grows palettes only once an in-memory cache seam
    /// exists (follow-up filed with the search rework PR).
    var searchContext: SettingsSearchContext {
        SettingsSearchContext(
            editingStoredProfile: model.editingStoredProfile,
            mode: model.settingsMode,
            displayCount: model.displays.count,
            spaces: model.config.spaces.map(\.raw),
            profiles: model.profileSummaries.map(\.name),
            palettes: [],
            appRules: model.config.appRules.keys.sorted()
        )
    }
}
