import Foundation

/// Why the live target reports unsaved state that no draft leaf
/// carries (#1197). ONE verdict, read by the header's status
/// line, the save pill's presence and the pill's drift rows —
/// three surfaces that used to derive it apart and disagreed.
enum ProfileDrift: Equatable {
    /// A built-in layout is composing; nothing saved holds it.
    case builtIn
    /// The active profile stores no set for the connected
    /// screens.
    case screensUnsaved(profile: String)
    /// Nothing matches: the matched profile was deleted, or a
    /// Lua-owned config adopts no Standard.
    case noMatch
}

extension SettingsModel {
    /// Whether the LIVE target has drift to report. False while
    /// a stored profile is on the table: its draft owns the pill
    /// then, and the header hides divergence the same way.
    var liveDrift: Bool {
        profileDirty && !editingStoredProfile
    }

    /// The drift's shape, nil without `liveDrift`.
    var profileDrift: ProfileDrift? {
        guard liveDrift else { return nil }
        if activeStandard != nil { return .builtIn }
        if let name = activeProfile {
            return .screensUnsaved(profile: name)
        }
        return .noMatch
    }
}
