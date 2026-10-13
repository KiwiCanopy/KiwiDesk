import Foundation
import KiwiDeskCore
import SwiftUI

/// The key panel's three sides (#2229, #2246): the window
/// switcher's list, the shortcuts sheet and the layout picker's
/// tiles, one field above all three, in the order of their keys
/// J K L. ⇥ steps forward and ⇧⇥ back, wrapping, and each side's
/// own shortcut reaches it while the panel is up.
enum JumpScope: CaseIterable, Equatable {
    case windows
    case shortcuts
    case layouts

    /// The side ⇥ (forward) or ⇧⇥ reaches, wrapping.
    func stepped(forward: Bool) -> JumpScope {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        let offset = forward ? 1 : all.count - 1
        return all[(index + offset) % all.count]
    }

    /// The scope switch's VoiceOver name.
    @MainActor static var switchName: String {
        L("jump.scope.label", "Show")
    }

    /// The switch's segment and the footer's ⇥ hint.
    @MainActor var title: String {
        switch self {
        case .windows: return L("jump.scope.windows", "Windows")
        case .shortcuts:
            return L("jump.scope.shortcuts", "Shortcuts")
        case .layouts: return L("jump.scope.layouts", "Layouts")
        }
    }

    /// The side's VoiceOver name, and the noun its shortcut row
    /// shows (#2245, `ShortcutsPanelNounTests`).
    @MainActor var panelName: String {
        switch self {
        case .windows: return L("jump.panel.ax_label", "Window switcher")
        case .shortcuts:
            return L("shortcuts.panel.ax_label", "Shortcuts panel")
        case .layouts:
            return L("layout_picker.panel.ax_label", "Layout picker")
        }
    }

    /// The Lua the side's own shortcut runs, whose live chord the
    /// switch prints (#2245).
    var lua: String {
        switch self {
        case .windows: return KeybindingCatalog.jumpToWindow.lua
        case .shortcuts: return ShortcutsOpenBinding.lua
        case .layouts: return KeybindingCatalog.showLayoutPicker.lua
        }
    }

    /// The field's placeholder and its VoiceOver name.
    @MainActor var fieldName: String {
        switch self {
        case .windows: return L("jump.field.label", "Jump to window")
        case .shortcuts:
            return L("shortcuts.field.label", "Find a shortcut")
        case .layouts:
            return L("layout_picker.field.label", "Choose a layout")
        }
    }
}
