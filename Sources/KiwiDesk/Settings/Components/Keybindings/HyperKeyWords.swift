import KiwiDeskCore
import SwiftUI

/// The Hyper key row's words (#1870): Core names the key's class
/// and side, the GUI writes the sentence (#96). The caption labels
/// what the recorded key now does; the `?` teaches (gui.md, #94).
@MainActor
enum HyperKeyWords {
    static var title: String { SettingsCatalog.shortcuts.hyperKey.text }

    static var help: String {
        L(
            "shortcuts.hyper_key.help",
            "Hyper is an extra modifier key that no app uses. A "
                + "shortcut on Hyper alone never collides; combined "
                + "with ⌘, ⌥ or ⌃, an enabled macOS shortcut on the "
                + "same keys still wins. Unlike shortcut recording, "
                + "this row "
                + "tells left from right: Right ⌘ can be Hyper while "
                + "Left ⌘ stays ⌘. While KiwiDesk manages your "
                + "windows, the key you pick stops doing its own job."
        )
    }

    /// The key as the row names it: "Caps Lock", "Right ⌘", "F13".
    /// One key per sided modifier: the side is an adjective that
    /// agrees with each key's own noun (localization.md).
    static func name(_ key: HyperSourceKey) -> String {
        switch key {
        case .capsLock:
            return L("shortcuts.hyper_key.caps_lock", "Caps Lock")
        case .leftCommand:
            return L("shortcuts.hyper_key.left_command", "Left ⌘")
        case .rightCommand:
            return L("shortcuts.hyper_key.right_command", "Right ⌘")
        case .leftOption:
            return L("shortcuts.hyper_key.left_option", "Left ⌥")
        case .rightOption:
            return L("shortcuts.hyper_key.right_option", "Right ⌥")
        case .leftControl:
            return L("shortcuts.hyper_key.left_control", "Left ⌃")
        case .rightControl:
            return L("shortcuts.hyper_key.right_control", "Right ⌃")
        case .leftShift:
            return L("shortcuts.hyper_key.left_shift", "Left ⇧")
        case .rightShift:
            return L("shortcuts.hyper_key.right_shift", "Right ⇧")
        default:
            return key.rawValue.uppercased()  // F1 … F20
        }
    }

    /// What the recorded key now does, or the invitation when no
    /// key is set.
    static func caption(_ key: HyperSourceKey?) -> String {
        guard let key else {
            return L(
                "shortcuts.hyper_key.caption.empty",
                "Turn one key into Hyper (✦) — an extra modifier like ⌘ "
                    + "or ⌥. Most people pick Caps Lock (⇪)."
            )
        }
        switch key.kind {
        case .capsLock:
            return L(
                "shortcuts.hyper_key.caption.caps_lock",
                "Caps Lock is now Hyper and no longer turns on "
                    + "capitals. Quitting KiwiDesk gives it back."
            )
        case .modifier:
            return L(
                "shortcuts.hyper_key.caption.modifier",
                "%1$@ is now Hyper; %2$@ still works as %3$@. Quitting "
                    + "KiwiDesk gives it back.",
                name(key),
                name(twin(of: key)),
                glyph(key)
            )
        case .systemKey:
            return L(
                "shortcuts.hyper_key.caption.system_key",
                "%1$@ is now Hyper and stops its own action. Quitting "
                    + "KiwiDesk gives it back.",
                name(key)
            )
        case .spare:
            return L(
                "shortcuts.hyper_key.caption.spare",
                "%1$@ is now Hyper. It had no other job. Quitting "
                    + "KiwiDesk gives it back.",
                name(key)
            )
        }
    }

    /// Why a chosen key is not working, or nil while it is.
    static func trouble(_ status: HyperKeyStatus) -> String? {
        switch status {
        case .refused(let foreign?) where foreign.claimable:
            return L(
                "shortcuts.hyper_key.refused_claimable",
                "%1$@ is already remapped to %2$@ on this Mac, so "
                    + "Hyper stays off. That is the remap KiwiDesk "
                    + "would set itself, which a remapping app can leave "
                    + "behind when it quits.",
                name(foreign.source),
                name(foreign.destination)
            )
        case .refused(let foreign?):
            return L(
                "shortcuts.hyper_key.refused_named",
                "%1$@ is already remapped to %2$@ on this Mac, so "
                    + "Hyper stays off. A remap stays after the app "
                    + "that set it quits, until that app turns it off "
                    + "or the Mac restarts.",
                name(foreign.source),
                name(foreign.destination)
            )
        case .refused(nil):
            return L(
                "shortcuts.hyper_key.refused",
                "Another app already remaps a key on this Mac, so "
                    + "Hyper stays off. A remap stays after the app "
                    + "that set it quits, until that app turns it off "
                    + "or the Mac restarts."
            )
        case .failed:
            return L(
                "shortcuts.hyper_key.failed",
                "macOS did not answer the key remap, so Hyper stays "
                    + "off for now."
            )
        case .on, .off:
            return nil
        }
    }

    /// Hyper is on and the active layer has no ✦ row, so pressing
    /// the key does nothing (#2480); one sentence for every key kind.
    static func noShortcut(_ key: HyperSourceKey) -> String {
        L(
            "shortcuts.hyper_key.caption.no_shortcut",
            "%1$@ is now Hyper, but no active shortcut uses ✦, so "
                + "pressing it does nothing. Quitting KiwiDesk gives it "
                + "back.",
            name(key)
        )
    }

    /// A key chosen while KiwiDesk manages no windows: the remap
    /// waits for Start Tiling.
    static var paused: String {
        L(
            "shortcuts.hyper_key.paused",
            "Hyper turns on once KiwiDesk manages your windows."
        )
    }

    static var typesText: String {
        L(
            "shortcuts.hyper_key.types_text",
            "This key types text, so it can't be Hyper. Pick a key "
                + "you don't type with."
        )
    }

    static var record: String {
        L("shortcuts.hyper_key.record", "Record key")
    }

    static var pressKey: String {
        L("shortcuts.hyper_key.press", "Press a key…")
    }

    static var clear: String {
        L("shortcuts.hyper_key.clear", "Turn the Hyper key off")
    }

    private static func glyph(_ key: HyperSourceKey) -> String {
        switch key {
        case .leftCommand, .rightCommand: return "⌘"
        case .leftOption, .rightOption: return "⌥"
        case .leftControl, .rightControl: return "⌃"
        case .leftShift, .rightShift: return "⇧"
        default: return ""
        }
    }

    private static func twin(of key: HyperSourceKey) -> HyperSourceKey {
        switch key {
        case .leftCommand: return .rightCommand
        case .rightCommand: return .leftCommand
        case .leftOption: return .rightOption
        case .rightOption: return .leftOption
        case .leftControl: return .rightControl
        case .rightControl: return .leftControl
        case .leftShift: return .rightShift
        case .rightShift: return .leftShift
        default: return key
        }
    }
}
