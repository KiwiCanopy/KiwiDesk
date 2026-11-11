import AppKit
import KiwiDeskCore

/// What the footer and a pick read of the panel's state: the
/// modifiers that count now, and whether anything is selected.
extension JumpModel {
    /// ⇧, ⌥ and ⌘ as held now, for the footer's one lit hint.
    var heldModifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if shiftHeld { flags.insert(.shift) }
        if optionHeld { flags.insert(.option) }
        if commandHeld { flags.insert(.command) }
        return flags
    }

    /// Whether the side shown has a selection a pick acts on.
    var hasSelection: Bool {
        switch scope {
        case .windows: return list.selected != nil
        case .shortcuts: return false
        case .view: return view?.selected?.isApplicable == true
        case .desktops: return desktops?.place != nil
        }
    }
}
