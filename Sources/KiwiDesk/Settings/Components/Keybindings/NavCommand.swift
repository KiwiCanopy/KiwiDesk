import KiwiDeskCore

/// Preset navigation action descriptor
/// (`KeybindingImportClassifier`, `KeyBinding.label`).
struct NavCommand: Identifiable, Hashable {
    let label: String
    let lua: String
    /// Space icon shown before label (#68 §6.5).
    var icon: String? = nil
    /// Localized label closure (`KeyLayer.sameAction`).
    var displayLabel: @MainActor () -> String = { "" }
    /// Contextual help closure for limitation tooltip (`NavRow`, #94, #420).
    var help: (@MainActor () -> String)? = nil
    /// Why this row's ACTION cannot run right now. Not a disabled
    /// flag: the row stays fully editable — recording a key for a
    /// Desktop that is away is exactly what a docked-and-undocked
    /// user is doing; it dims and says why (`keybindingRowStyle`).
    /// Excluded from `==`/`hash` with `displayLabel` and `help`:
    /// identity stays label + Lua + icon, which the import
    /// classifier and `NavRow`'s keying depend on.
    var unavailable: (@MainActor () -> String)? = nil
    var id: String { lua }

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
