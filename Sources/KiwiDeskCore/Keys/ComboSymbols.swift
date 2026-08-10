import Foundation

/// Renders a `KeyCombo` as the compact macOS-native glyph string
/// menus use (`⇧⌘,`, `⌃⌥←`): modifier symbols in the canonical
/// ⌃⌥⇧⌘ order (Command last, adjacent to the key) followed by the
/// key glyph, with **no `+` separator**.
///
/// Dropping the separator resolves the combinator ambiguity #23
/// raises: with no `+` between tokens, any `+` that appears is the
/// key itself (`⌘+`), never a "together with" combinator.
///
/// The glyph for a printable key is resolved through the *active*
/// keyboard layout by the injected `layoutChar` closure — the GUI
/// backs it with `UCKeyTranslate`, so a German layout shows `+`
/// where a US layout shows `]`. Non-printable keys (arrows,
/// return, function keys) use fixed symbols; when the layout
/// lookup yields nothing, the US key name falls back to a symbol.
/// This type is pure and Core-testable — only the injected closure
/// touches the OS.
public enum ComboSymbols {
    /// The combo as a native glyph string. `layoutChar` maps a
    /// virtual key code to its base character on the active
    /// layout, or nil for keys with no printable character.
    public static func render(
        _ combo: KeyCombo,
        layoutChar: (UInt32) -> String?
    ) -> String {
        modifierSymbols(combo.modifiers)
            + keyGlyph(combo.keyCode, layoutChar)
    }

    /// Modifier symbols in the macOS-canonical ⌃⌥⇧⌘ order.
    ///
    /// Public because a modifier set is a thing the GUI names on
    /// its own, without a key beside it: the keyboard preview's
    /// chips label one layer each (⌥, ⌃⌥, …) and `render` can
    /// only ever draw a whole combo. The GUI's own
    /// `ChordRecorder` is not a second copy of this — it renders
    /// `NSEvent.ModifierFlags` mid-chord, before a `KeyCombo`
    /// exists.
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

    /// A key's character, capitalised — but only where
    /// capitalising it stays ONE key's worth of glyph.
    ///
    /// German ß uppercases to "SS", so a shortcut on that key
    /// rendered `⌃⌥SS`: two characters for a key the user's
    /// keyboard prints as one, in every surface that draws a
    /// combo (the recorder, the Shortcuts list, the draft diff
    /// rows, the quick menu). Turkish ı and Greek final sigma
    /// have the same shape of problem, which is why the rule is
    /// mechanical rather than a ß special case.
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

    /// Fixed glyphs for keys that carry no printable character —
    /// arrows, editing, whitespace, and function keys. Nil means
    /// the key is printable and resolves through the layout.
    static func specialKeyGlyph(_ code: UInt32) -> String? {
        specials[code]
    }

    private static let specials: [UInt32: String] = [
        123: "←", 124: "→", 125: "↓", 126: "↑",
        36: "↩", 76: "⌤", 48: "⇥", 49: "␣",
        51: "⌫", 117: "⌦", 53: "⎋",
        115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        122: "F1", 120: "F2", 99: "F3", 118: "F4",
        96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]

    /// A symbol for a US key name when the active layout gives no
    /// character (punctuation words → their glyph; a bare letter/
    /// digit uppercases). Mirrors `KeyCombo.keyName` word aliases.
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
