import KiwiDeskCore

/// Preset navigation action descriptor
/// (`KeybindingImportClassifier`, `KeyBinding.label`).
struct NavCommand: Identifiable, Hashable {
    let label: String
    let lua: String
    /// An identity glyph — a Space's or a Desktop's (#68 §6.5). A
    /// verb's glyph lives in `ShortcutsReferenceBuilder.verbIcon`,
    /// never here (#2530); both the key panel and Settings draw
    /// through `ShortcutsReferenceBuilder.icon(for:)` (#2670).
    var icon: String? = nil
    /// Localized label closure (`KeyLayer.sameAction`).
    var displayLabel: @MainActor () -> String = { "" }
    /// Contextual help closure for limitation tooltip (`NavRow`, #94, #420).
    var help: (@MainActor () -> String)? = nil
    /// Explanation of why command action cannot run in current environment
    /// (`keybindingRowStyle`).
    var unavailable: (@MainActor () -> String)? = nil
    /// A live Space the profile does not hold, whose chip the row
    /// wears (#1827).
    var liveOnly: LiveOnlySpace.Kind? = nil
    /// Which stored Lua this row owns, where more than its own
    /// spelling does — a lens row owns every spelling of its lens
    /// (#2103 ruling 39); nil owns `lua` alone.
    var owns: (@Sendable (String) -> Bool)? = nil
    var id: String { lua }

    /// Whether a stored binding's Lua is this row's.
    func runs(_ stored: String) -> Bool {
        owns?(stored) ?? (stored == lua)
    }

    @MainActor var resolvedLabel: String {
        let resolved = displayLabel()
        return resolved.isEmpty ? label : resolved
    }

    static func == (lhs: NavCommand, rhs: NavCommand) -> Bool {
        lhs.label == rhs.label && lhs.lua == rhs.lua
            && lhs.icon == rhs.icon
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(label)
        hasher.combine(lua)
        hasher.combine(icon)
    }
}

/// Collapsible group of navigation commands.
struct NavGroup: Identifiable {
    let title: String
    let commands: [NavCommand]
    var id: String { title }
}
