import Carbon.HIToolbox
import Foundation

/// A parsed keyboard shortcut ("ctrl+alt+r", "cmd+shift+left").
public struct KeyCombo: Hashable, Sendable {
    public let keyCode: UInt32
    public let modifiers: HotkeyModifiers

    public init(keyCode: UInt32, modifiers: HotkeyModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Parses "mod+mod+key". Modifier aliases: cmd/command,
    /// alt/opt/option, ctrl/control, shift. Returns nil for
    /// unknown keys or empty input.
    public static func parse(_ text: String) -> KeyCombo? {
        let parts = text.lowercased()
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard let keyName = parts.last, !keyName.isEmpty
        else { return nil }
        guard let keyCode = keyCodes[keyName] else {
            return nil
        }
        var modifiers: HotkeyModifiers = []
        for part in parts.dropLast() {
            switch part {
            case "cmd", "command":
                modifiers.insert(.command)
            case "alt", "opt", "option":
                modifiers.insert(.option)
            case "ctrl", "control":
                modifiers.insert(.control)
            case "shift":
                modifiers.insert(.shift)
            default:
                return nil
            }
        }
        return KeyCombo(
            keyCode: keyCode,
            modifiers: modifiers
        )
    }

    /// Formats a captured key event into a combo string using
    /// the words printed on Apple keyboards
    /// (`"control+option+r"`) so users can read exactly what a
    /// binding is. `parse` round-trips it and also accepts the
    /// short aliases (ctrl / alt / cmd) in hand-written configs.
    /// Returns nil for key codes with no known name (so the
    /// recorder can reject them). Modifier order follows ⌃⌥⇧⌘.
    ///
    /// Carbon hotkeys can't tell left from right modifiers
    /// (that needs an event tap + Input Monitoring, which
    /// KiwiDesk avoids), so the two sides are intentionally
    /// unified here.
    public static func comboString(
        keyCode: UInt32,
        command: Bool,
        option: Bool,
        control: Bool,
        shift: Bool
    ) -> String? {
        guard let key = keyName(for: keyCode) else { return nil }
        var parts: [String] = []
        if control { parts.append("control") }
        if option { parts.append("option") }
        if shift { parts.append("shift") }
        if command { parts.append("command") }
        parts.append(key)
        return parts.joined(separator: "+")
    }

    /// This combo formatted as a canonical string
    /// (`"control+option+r"`), reversing `parse`. Returns nil
    /// when the key code has no known name. Used when importing
    /// live bindings back into the GUI (#4).
    public func comboString() -> String? {
        Self.comboString(
            keyCode: keyCode,
            command: modifiers.contains(.command),
            option: modifiers.contains(.option),
            control: modifiers.contains(.control),
            shift: modifiers.contains(.shift)
        )
    }

    /// The canonical name for a key code (reverse of
    /// `keyCodes`). Codes that carry both a symbol and a word
    /// alias resolve to the readable word form for display.
    static func keyName(for code: UInt32) -> String? {
        let overrides: [UInt32: String] = [
            36: "return", 51: "delete", 53: "escape",
            41: "semicolon", 43: "comma", 47: "period",
            44: "slash", 42: "backslash", 39: "quote",
            50: "grave", 27: "minus", 24: "equal",
            30: "rightbracket", 33: "leftbracket",
        ]
        if let name = overrides[code] { return name }
        return keyCodes.first { $0.value == code }?.key
    }

    /// US-layout virtual key codes (Carbon kVK_*).
    static let keyCodes: [String: UInt32] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5,
        "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12,
        "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
        "5": 23, "=": 24, "9": 25, "7": 26, "-": 27,
        "8": 28, "0": 29, "]": 30, "o": 31, "u": 32,
        "[": 33, "i": 34, "p": 35, "l": 37, "j": 38,
        "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43,
        "/": 44, "n": 45, "m": 46, ".": 47, "`": 50,
        // Word aliases for punctuation (skhd / AeroSpace
        // convention); the symbol forms above still work.
        "semicolon": 41, "comma": 43, "period": 47,
        "slash": 44, "backslash": 42, "quote": 39,
        "apostrophe": 39, "grave": 50, "backtick": 50,
        "minus": 27, "equal": 24, "leftbracket": 33,
        "rightbracket": 30,
        "return": 36, "enter": 36, "tab": 48, "space": 49,
        "delete": 51, "backspace": 51, "escape": 53,
        "esc": 53, "left": 123, "right": 124, "down": 125,
        "up": 126, "home": 115, "end": 119, "pageup": 116,
        "pagedown": 121,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118,
        "f5": 96, "f6": 97, "f7": 98, "f8": 100,
        "f9": 101, "f10": 109, "f11": 103, "f12": 111,
    ]
}
