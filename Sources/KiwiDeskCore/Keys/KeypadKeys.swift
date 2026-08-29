import Foundation

/// The numeric keypad, and the one relation that makes it
/// usable: **its ten digits are the same key as their
/// number-row twin.** A binding authored as `4` fires from
/// either physical key; every other keypad key (`+ − × ÷ . =
/// enter clear`) is its own bindable key. Why it aliases rather
/// than adding ten distinct keys, why the set stays closed to
/// the digits, and why the keypad is not drawn on the Settings
/// board are argued once in `docs/design-decisions.md` ▸ "The
/// keypad's ten digits ARE their number-row twins"; the
/// obligations that fall out of it are in
/// `.claude/rules/input-and-animation.md`. (#1074)
///
/// This enum is the one home for the relation, and both readers
/// come to it: hotkey registration
/// (`KeybindingManager.activate`) registers the twin as a second
/// physical key, and `KeyCombo.keyName` canonicalises a captured
/// keypad press back to its digit.
///
/// **The invariant everything downstream leans on:** `names`
/// resolves `keypad0`…`keypad9` to the ROW code, so a parsed
/// `KeyCombo` can never carry a keypad digit code. That is why
/// conflict detection, the importer, `SystemShortcuts` and the
/// Settings board all stayed correct without an edit — they
/// compare and draw row codes, and only ever see row codes.
/// `KeypadKeysTests` pins it; breaking it would split conflict
/// detection from registration silently.
public enum KeypadKeys {
    /// The ten keypad digits: the keypad's own key code, the
    /// number-row code it stands for, and the digit it prints.
    ///
    /// One table with three columns rather than two and a
    /// derivation. The printed digit is a fact this table
    /// already holds, and recovering it from Apple's code
    /// numbering instead — which skips 90, so keypad `8` is 91 —
    /// would let an edited row shift every legend at once.
    /// `KeypadKeysTests` pins the `pad` column against the
    /// Carbon `kVK_ANSI_Keypad*` constants and the pad↔row
    /// PAIRING against those same constants, so a transposed
    /// pair reds rather than binding the wrong digit.
    public typealias Digit = (
        pad: UInt32, row: UInt32, legend: String
    )

    public static let digits: [Digit] = [
        (82, 29, "0"), (83, 18, "1"), (84, 19, "2"),
        (85, 20, "3"), (86, 21, "4"), (87, 23, "5"),
        (88, 22, "6"), (89, 26, "7"), (91, 28, "8"),
        (92, 25, "9"),
    ]

    /// Keypad digit key code → its number-row twin's code.
    public static let digitTwins: [UInt32: UInt32] = Dictionary(
        uniqueKeysWithValues: digits.map { ($0.pad, $0.row) }
    )

    /// The keypad keys that are NOT digits, name → code. These
    /// are their own bindable keys — nothing on the main block
    /// is their twin — so they join `KeyCombo.keyCodes` the way
    /// any other key name does.
    ///
    /// `keypad0`…`keypad9` join it too, but as ALIASES resolving
    /// to the number-row code (see the invariant above): a
    /// config author who writes `keypad4` means the key this
    /// enum says is `4`, and gets it, rather than an "unknown
    /// key" rejection for a spelling the rule makes reasonable.
    public static let names: [String: UInt32] = {
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
        for entry in digits {
            map["keypad\(entry.legend)"] = entry.row
        }
        return map
    }()

    /// The display name `KeyCombo.keyName` must resolve a
    /// number-row digit to, pinned rather than left to the
    /// name→code map's iteration order. `names` gives each digit
    /// code a second spelling (`keypad4`), and the unpinned
    /// fallback picks whichever the dictionary yields first — so
    /// without these a captured `4` could render as `keypad4`.
    public static let displayOverrides: [UInt32: String] =
        Dictionary(
            uniqueKeysWithValues: digits.map {
                ($0.row, $0.legend)
            }
        )

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
}
