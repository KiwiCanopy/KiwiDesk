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

    /// The segment's title. Personal shares KiwiHub's word for the
    /// user's own shortcut groups, so the two never differ.
    @MainActor var title: String {
        switch self {
        case .builtIn:
            return L("shortcuts.segment.built_in", "Built-in")
        case .personal:
            return L("shortcuts.panel.custom", "Personal")
        case .mouse:
            return SettingsCatalog.shortcuts.gestures.control.text
        }
    }

    /// The part a binding's row is drawn in: a shipped action's row
    /// on Built-in, an app's, a key sequence's or a Lua shortcut on
    /// Personal.
    init(_ binding: KeyBinding) {
        self = binding.kind == .navigation ? .builtIn : .personal
    }
}
