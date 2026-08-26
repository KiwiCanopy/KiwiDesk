import Foundation
import KiwiDeskCore

/// The dashboard model's reads derived from `core` — values it
/// holds no state for and forwards from the engine.
///
/// Split from `SettingsModel.swift` on the §2.1 file ceiling,
/// which that file reached with its stored properties alone: a
/// `@Published` stored property cannot live in an extension, so
/// what could move was exactly what computes.
///
/// **Small on purpose, and not a home for "everything derived".**
/// A derivation belongs beside the value it derives FROM, which
/// is why the two edit-target reads (`editingProfile`,
/// `editingStoredProfile`) sit in
/// `SettingsModel+EditTarget.swift` with the state machine that
/// owns `target`, and the layout-drift and profile reads sit in
/// their own files. What is left here is what derives from
/// `core` itself and belongs to no subsystem — so a new
/// computed property joins its subsystem's file, and lands here
/// only when it genuinely has none.
extension SettingsModel {
    var configURL: URL { core.configURL }
    var displays: [Display] { core.state.workspaces.allDisplays }

    /// Whether the raw Lua editor is currently shown.
    var editingLua: Bool { forcedLuaEditor || showLuaEditor }
}
