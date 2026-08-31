import Foundation

/// Formats `KeyCombo` into macOS native glyph string
/// (`⇧⌘,`, `⌃⌥←`, #23).
///
/// Modifiers appear in canonical `⌃⌥⇧⌘` order with no `+` delimiter
/// (#23). Printable characters resolve via active layout
/// (`UCKeyTranslate`).
public enum ComboSymbols {
    /// Renders combo into native glyph string using provided layout
    /// translator.
    public static func render(
        _ combo: KeyCombo,
        layoutChar: (UInt32) -> String?
    ) -> String {
        modifierSymbols(combo.modifiers)
            + keyGlyph(combo.keyCode, layoutChar)
    }

    /// Formats modifiers in canonical macOS `⌃⌥⇧⌘` order
    /// (`ChordRecorder`).
    public static func modifierSymbols(
        _ modifiers: HotkeyModifiers
    ) -> String {
        var out = ""
        if modifiers.contains(.control) { out += "⌃" }
        if modifiers.contains(.option) { out += "⌥" }
        if modifiers.contains(.shift) { out += "⇧" }
        if modifiers.contains(.command) { out += "⌘" }
        return out
    }

    /// Capitalises character if character count remains 1
    /// (avoids German `ß` -> `SS`).
    public static func capitalisedGlyph(_ char: String) -> String {
        let upper = char.uppercased()
        return upper.count == char.count ? upper : char
    }

    private static func keyGlyph(
        _ code: UInt32,
        _ layoutChar: (UInt32) -> String?
    ) -> String {
        if let special = specialKeyGlyph(code) { return special }
        if let char = layoutChar(code), !char.isEmpty {
            return capitalisedGlyph(char)
        }
        if let name = KeyCombo.keyName(for: code) {
            return fallbackGlyph(name)
        }
        return ""
    }

    /// Returns fixed symbol for non-printable keys (#1074).
    static func specialKeyGlyph(_ code: UInt32) -> String? {
        specials[code]
    }

    private static let specials: [UInt32: String] = [
        123: "←", 124: "→", 125: "↓", 126: "↑",
        36: "↩", 76: "⌤", 48: "⇥", 49: "␣",
        71: "⌧",
        51: "⌫", 117: "⌦", 53: "⎋",
        115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        122: "F1", 120: "F2", 99: "F3", 118: "F4",
        96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]

    /// Punctuation and named key symbol fallback (`KeyCombo.keyName`).
    static func fallbackGlyph(_ name: String) -> String {
        let symbols: [String: String] = [
            "comma": ",", "period": ".", "slash": "/",
            "backslash": "\\", "quote": "'", "grave": "`",
            "minus": "-", "equal": "=", "semicolon": ";",
            "leftbracket": "[", "rightbracket": "]",
        ]
        return symbols[name] ?? name.uppercased()
    }
}
