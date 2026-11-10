import KiwiDeskCore

/// The three parts the Shortcuts page's segmented control shows one
/// at a time (#3184): what KiwiDesk ships, what the user adds, and
/// what the mouse and trackpad do. The selection lives on
/// `SettingsNavigation` (#1127); a search hit picks the part that
/// holds it.
enum ShortcutsSegment: String, CaseIterable, Identifiable, Hashable {
    case builtIn
    case personal
    case mouse

    var id: String { rawValue }

    /// The segment's title. Personal is KiwiHub's word for the
    /// user's own shortcuts (`ShortcutGroup.personalTitle`).
    @MainActor var title: String {
        switch self {
        case .builtIn:
            return L("shortcuts.segment.built_in", "Built-in")
        case .personal:
            return ShortcutGroup.personalTitle
        case .mouse:
            return SettingsCatalog.shortcuts.gestures.control.text
        }
    }
}
