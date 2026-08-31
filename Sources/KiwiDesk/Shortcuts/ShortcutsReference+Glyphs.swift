import Foundation
import KiwiDeskCore

/// Shortcut reference row glyphs and combo formatting (#820).
/// Panel-only by INTENT rather than access control: the §2.1
/// split cost these `private`, so keeping the shared catalog and
/// editor rows untouched is now an obligation on a future caller,
/// not something the compiler holds
/// (`ShortcutsReferenceBuilder`).
extension ShortcutsReferenceBuilder {
    /// SF Symbol icon name for compass-direction navigation commands.
    static func directionalIcon(for lua: String) -> String? {
        // A space or layer literally named a direction word would
        // false-match on the substring — those commands own their
        // own glyphs, so bail first.
        guard !lua.contains("_space"),
            !lua.contains("switch_layer")
        else { return nil }
        if lua.contains("\"left\"") { return "arrow.left" }
        if lua.contains("\"right\"") { return "arrow.right" }
        if lua.contains("\"up\"") { return "arrow.up" }
        if lua.contains("\"down\"") { return "arrow.down" }
        return nil
    }

    /// Numbered square icon fallback for space commands. Do NOT
    /// route the Space Bar's plain-digit fallback through here or
    /// this through it: this is a symbol slot with no boxed
    /// wrapper, so the bar's box-in-a-box problem (QA 2026-07-19)
    /// does not apply.
    static func spaceFallbackIcon(
        for lua: String
    ) -> String? {
        guard lua.contains("_space") else { return nil }
        if let id = quotedArg(in: lua), let n = Int(id),
            (0...50).contains(n)
        {
            return "\(n).square"
        }
        return "squares.below.rectangle"
    }

    /// Extracts the first quoted argument from a Lua call string.
    private static func quotedArg(in lua: String) -> String? {
        guard let open = lua.range(of: "(\"") else { return nil }
        let rest = lua[open.upperBound...]
        guard let close = rest.range(of: "\"") else { return nil }
        return String(rest[..<close.lowerBound])
    }

    /// Formats key combo string into glyphs (`ComboSymbols`, `KeyCombo`).
    static func glyphs(_ combo: String) -> String {
        guard let parsed = KeyCombo.parse(combo) else {
            return combo
        }
        return ComboSymbols.render(
            parsed,
            layoutChar: LayoutKeyGlyph.char
        )
    }
}
