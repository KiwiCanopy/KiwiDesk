import Foundation
import KiwiDeskCore

/// Core engine forwarding derivations for SettingsModel. Small on
/// purpose: a derivation belongs beside the value it derives FROM
/// (edit-target reads sit with their state machine); a value
/// lands here only when it has no subsystem.
extension SettingsModel {
    var configURL: URL { core.configURL }
    var displays: [Display] { core.state.workspaces.allDisplays }

    /// The count stepper's ▲ bound (#1382): Core's count of the
    /// scrolling slots the DRAFT fits on `space`'s screen — the
    /// widest connected one with no space, the Layout Defaults
    /// card — and the share's own floor with no screen known.
    /// The first live-machine read in Layout Defaults, stated on
    /// the issue as the cost.
    func scrollingColumnCap(for space: SpaceID?) -> Int {
        core.scrollingColumnCap(for: space, settings: config.settings)
            ?? ScrollSize.countCeiling
    }

    /// Whether the raw Lua editor is currently shown.
    var editingLua: Bool { forcedLuaEditor || showLuaEditor }
}
