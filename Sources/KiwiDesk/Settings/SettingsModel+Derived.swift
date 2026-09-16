import Foundation
import KiwiDeskCore

/// Core engine forwarding derivations for SettingsModel. Small on
/// purpose: a derivation belongs beside the value it derives FROM
/// (edit-target reads sit with their state machine); a value
/// lands here only when it has no subsystem.
extension SettingsModel {
    var configURL: URL { core.configURL }
    var displays: [Display] { core.state.workspaces.allDisplays }

    /// The count stepper's ▲ bound (#1382): Core's count of
    /// scrolling slots the DRAFT's terms fit on `space`'s own
    /// screen, or — with no space, the Layout Defaults card — on
    /// the widest connected one; the slider's own floor with no
    /// screen known. The first live-machine read in Layout
    /// Defaults, stated on the issue as the cost.
    func scrollingColumnCap(for space: SpaceID?) -> Int {
        let own =
            space.flatMap { core.state.workspaces.display(of: $0) }
            .flatMap { id in displays.first { $0.id == id } }
        let widest = displays.max {
            $0.visibleFrame.width < $1.visibleFrame.width
        }
        let screen = own ?? widest
        guard let screen else { return ScrollSize.fallbackMaxCount }
        return config.settings.scrollingColumnCap(
            visible: screen.visibleFrame,
            space: space
        )
    }

    /// Whether the raw Lua editor is currently shown.
    var editingLua: Bool { forcedLuaEditor || showLuaEditor }
}
