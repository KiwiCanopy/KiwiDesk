import Foundation
import KiwiDeskCore

/// The dashboard model's DERIVED reads: values computed from
/// `core` or from the edit target, holding no state of their own.
///
/// Split from `SettingsModel.swift` on the §2.1 file ceiling,
/// which that file reached with its stored properties alone. The
/// seam is the same one `SettingsModel+Refresh.swift` names from
/// the other side — state on the class, everything derived from
/// it one file over — and it is the only seam available here: a
/// `@Published` stored property cannot live in an extension, so
/// what moves is exactly what computes.
extension SettingsModel {
    var configURL: URL { core.configURL }
    var displays: [Display] { core.state.workspaces.allDisplays }

    /// Whether the raw Lua editor is currently shown.
    var editingLua: Bool { forcedLuaEditor || showLuaEditor }

    /// The stored profile being edited, or nil while live —
    /// derived from `target` (#64).
    var editingProfile: String? {
        if case .storedProfile(let name) = target {
            return name
        }
        return nil
    }

    /// Whether the dashboard is editing a stored profile rather
    /// than the live config (#18) — hides App Rules, renders
    /// the Shortcuts tab in override mode (#55 phase 7), and
    /// swaps the footer's save action. The editing surface
    /// lives in `SettingsModel+ProfileOverrides.swift`.
    var editingStoredProfile: Bool { target != .live }
}
