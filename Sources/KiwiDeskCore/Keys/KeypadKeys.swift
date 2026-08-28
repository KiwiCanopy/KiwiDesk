import Foundation

/// The numeric keypad, and the one relation that makes it
/// usable: **its ten digits are the same key as their
/// number-row twin.** A binding authored as `4` fires from
/// either physical key; every other keypad key (`+ − × ÷ . =
/// enter clear`) is its own bindable key.
///
/// Keep that set closed. The tempting generalisation — "the
/// keypad mirrors whatever character it prints" — needs an
/// exception the moment it is written, because keypad `+` has
/// no number-row twin at all (main-block `+` is `⇧=`), while
/// the digit-only rule never needs one.
///
/// Aliasing rather than ten more distinct keys follows the
/// platform: AppKit menu key-equivalents match on the
/// character, so `⌘1` and `⌘`+keypad-`1` are one shortcut in
/// essentially every Mac app. KiwiDesk binds by key code
/// instead — for international position-stability, not to tell
/// a keypad from a number row — so the twin has to be stated
/// somewhere, and this enum is the one place it is. Every
/// reader comes here rather than carrying a copy: hotkey
/// registration (`KeybindingManager.activate`, which registers
/// the twin beside the authored code) and naming
/// (`KeyCombo.keyName`, which canonicalises a keypad press back
/// to its digit so the recorder round-trips it).
///
/// The keypad is deliberately absent from the Settings board
/// (`KeyboardMatrix`): `PhysicalType` distinguishes ANSI, ISO
/// and JIS, and macOS exposes no "a keypad is attached" signal,
/// so drawing one would show every laptop a block of keys it
/// does not have. Bindable-but-undrawn is the existing shape —
/// `f1`–`f12`, `home`, `end`, `pageup` and `pagedown` are all
/// bindable and none is on the board. (#1074)
public enum KeypadKeys {
    /// Keypad digit key code → its number-row twin's code.
    ///
    /// The literals are Carbon `kVK_ANSI_Keypad*` on the left
    /// and the `KeyCombo.keyCodes` number-row entries on the
    /// right; `KeypadKeysTests` pins both sides against the
    /// Carbon constants and against `keyCodes` itself, so a
    /// transposed pair reds rather than silently binding the
    /// wrong digit. Note 90 is not a keypad code — that is why
    /// keypad `8` is 91 and not the run 82…91 it looks like.
    public static let digitTwins: [UInt32: UInt32] = [
        82: 29,  // keypad 0 → 0
        83: 18,  // keypad 1 → 1
        84: 19,  // keypad 2 → 2
        85: 20,  // keypad 3 → 3
        86: 21,  // keypad 4 → 4
        87: 23,  // keypad 5 → 5
        88: 22,  // keypad 6 → 6
        89: 26,  // keypad 7 → 7
        91: 28,  // keypad 8 → 8
        92: 25,  // keypad 9 → 9
    ]

    /// The keypad keys that are NOT digits, name → code. These
    /// are their own bindable keys — nothing on the main block
    /// is their twin — so they join `KeyCombo.keyCodes` the way
    /// any other key name does.
    ///
    /// `keypad0`…`keypad9` join it too, but as ALIASES resolving
    /// to the number-row code: a config author who writes
    /// `keypad4` means the key this enum says is `4`, and gets
    /// it, rather than an "unknown key" rejection for a spelling
    /// the rule makes reasonable.
    public static var names: [String: UInt32] {
        var map: [String: UInt32] = [
            "keypadplus": 69,
            "keypadminus": 78,
            "keypadmultiply": 67,
            "keypaddivide": 75,
            "keypaddecimal": 65,
            "keypadequals": 81,
            "keypadenter": 76,
            "keypadclear": 71,
        ]
        for (pad, row) in digitTwins {
            map["keypad\(digitLegend(pad))"] = row
        }
        return map
    }

    /// The display name `KeyCombo.keyName` must resolve a
    /// number-row digit to, pinned rather than left to the
    /// name→code map's iteration order. `names` gives each digit
    /// code a second spelling (`keypad4`), and the unpinned
    /// fallback picks whichever the dictionary yields first —
    /// so without these a captured `4` could render as
    /// `keypad4`.
    public static var displayOverrides: [UInt32: String] {
        var map: [UInt32: String] = [:]
        for (pad, row) in digitTwins {
            map[row] = digitLegend(pad)
        }
        return map
    }

    /// The number-row code a keypad digit stands for, or nil
    /// when `code` is not a keypad digit. The direction naming
    /// matters: a keypad press arrives and must be *canonicalised
    /// to the row*, which is this one.
    public static func rowTwin(of code: UInt32) -> UInt32? {
        digitTwins[code]
    }

    /// The keypad code that also has to be registered for an
    /// authored number-row `code`, or nil when the key has no
    /// keypad twin. The other direction: a binding is stored
    /// against the row code and needs the keypad hotkey too.
    public static func keypadTwin(of code: UInt32) -> UInt32? {
        digitTwins.first { $0.value == code }?.key
    }

    /// The digit a keypad code prints, derived from the twin
    /// table's own ordering rather than restated: keypad `0` is
    /// the lowest code, so the run 82…92 (minus the absent 90)
    /// carries `0`…`9` in order.
    private static func digitLegend(_ pad: UInt32) -> String {
        let ordered = digitTwins.keys.sorted()
        guard let index = ordered.firstIndex(of: pad) else {
            return ""
        }
        return String(index)
    }
}
