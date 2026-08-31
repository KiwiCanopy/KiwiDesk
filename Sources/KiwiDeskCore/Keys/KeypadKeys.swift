import Foundation

/// Numeric keypad mappings and digit aliasing to number-row keys
/// (#1074, `docs/design-decisions.md`,
/// `.claude/rules/input-and-animation.md`).
/// Resolves keypad digits to row codes so `KeyCombo`, `SystemShortcuts`,
/// and Settings stay unified (`KeypadKeysTests`).
public enum KeypadKeys {
    /// Keypad digit tuple: (pad key code, number row key code,
    /// string legend). Three columns, not two plus a derivation —
    /// Apple's code numbering skips 90, so deriving the legend
    /// would let one edited row shift every legend at once
    /// (`KeypadKeysTests`, `kVK_ANSI_Keypad*`).
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

    /// Named non-digit keypad keys and digit aliases (`KeyCombo.keyCodes`).
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

    /// Display string overrides for number-row digits (`KeyCombo.keyName`).
    public static let displayOverrides: [UInt32: String] =
        Dictionary(
            uniqueKeysWithValues: digits.map {
                ($0.row, $0.legend)
            }
        )

    /// Returns number-row twin for keypad digit code.
    public static func rowTwin(of code: UInt32) -> UInt32? {
        digitTwins[code]
    }

    /// Returns keypad twin for number-row key code
    /// (`KeybindingManager.activate`).
    public static func keypadTwin(of code: UInt32) -> UInt32? {
        digitTwins.first { $0.value == code }?.key
    }
}
