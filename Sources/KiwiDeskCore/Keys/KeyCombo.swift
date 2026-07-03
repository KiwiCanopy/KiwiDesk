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
