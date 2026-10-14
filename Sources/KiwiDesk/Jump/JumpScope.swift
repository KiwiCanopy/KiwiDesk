import Foundation
import KiwiDeskCore
import SwiftUI

/// KiwiHub's three sides (#2229, #2246, #2265): the window
/// switcher's list, the shortcuts sheet and the layout picker's
/// tiles, one field above all three, in the order of their keys
/// J K L. ⇥ steps forward and ⇧⇥ back, wrapping, and each side's
/// own shortcut reaches it while the panel is up. One enum with
/// Core's, so the panel and `kiwihub.show` cannot map a side two
/// ways.
typealias JumpScope = KiwiHubSide

extension KiwiHubSide {
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

    /// The whole panel's VoiceOver name, the product name around
    /// every side's (#2265).
    @MainActor static var panelName: String {
        L("kiwihub.name", "KiwiHub")
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

    /// The field's placeholder and its VoiceOver name.
    @MainActor var fieldName: String {
        switch self {
        case .windows: return L("jump.field.label", "Jump to window")
        case .shortcuts:
            return L("shortcuts.field.label", "Search shortcuts")
        case .layouts:
            return L("layout_picker.field.label", "Choose a layout")
        }
    }
}
