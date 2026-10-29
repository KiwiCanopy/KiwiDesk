import Foundation
import KiwiDeskCore

/// Core engine forwarding derivations for SettingsModel. Small on
/// purpose: a derivation belongs beside the value it derives FROM
/// (edit-target reads sit with their state machine); a value
/// lands here only when it has no subsystem.
extension SettingsModel {
    var configURL: URL { core.configURL }
    var displays: [Display] { core.state.workspaces.allDisplays }

    /// Every name a new or renamed draft Space may not take: the
    /// draft's, and the live Spaces it does not hold (#1790), so a
    /// "+" never draws a second row for a temporary Space. Read by
    /// both Space row lists (#2737).
    var takenSpaceNames: [SpaceID] {
        config.spaces + liveOnlySpaces.map(\.id)
    }

    /// App Rules in the draft — pins and floats — counted once for
    /// Home's card and Simple's header (#2737).
    var appRuleCount: Int {
        config.appRules.count + config.floatRules.count
    }

    /// The count stepper's ▲ bound (#1382): Core's count of the
    /// scrolling slots the DRAFT fits on `space`'s screen — the
    /// widest connected one with no space, the Layout Defaults
    /// card — and the share's own floor with no screen known.
    func scrollingColumnCap(for space: SpaceID?) -> Int {
        core.scrollingColumnCap(for: space, settings: config.settings)
            ?? ScrollSize.countCeiling
    }

    /// Whether the raw Lua editor is currently shown.
    var editingLua: Bool { forcedLuaEditor || showLuaEditor }
}
