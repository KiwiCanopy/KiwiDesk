import Foundation
import KiwiDeskCore

/// Shortcut reference row glyphs and combo string formatting
/// (`ShortcutsReferenceBuilder`, #820).
extension ShortcutsReferenceBuilder {
    /// SF Symbol icon name for compass-direction navigation commands.
    static func directionalIcon(for lua: String) -> String? {
        guard !lua.contains("_space"),
            !lua.contains("switch_layer")
        else { return nil }
        if lua.contains("\"left\"") { return "arrow.left" }
        if lua.contains("\"right\"") { return "arrow.right" }
        if lua.contains("\"up\"") { return "arrow.up" }
        if lua.contains("\"down\"") { return "arrow.down" }
        return nil
    }

    /// Numbered square icon fallback for Space switching commands.
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

    /// A verb row's glyph on the key panel's Shortcuts side
    /// (#2246): the layout cycle, the size quartet, the float and
    /// sticky toggles — wearing the marks the windows wear — and a
    /// layer switch. Panel-only; Settings draws glyphs only where
    /// one names a thing.
    static func verbIcon(for lua: String) -> String? {
        switch lua {
        case "KiwiDesk.cycle_mode()":
            return "rectangle.righthalf.inset.filled.arrow.right"
        case "KiwiDesk.cycle_mode(\"prev\")":
            return "rectangle.lefthalf.inset.filled.arrow.left"
        case "KiwiDesk.toggle_floating()":
            return FloatingStyle.symbolName
        case "KiwiDesk.toggle_sticky()":
            return StickyStyle.symbolName
        case "KiwiDesk.toggle_display_sticky()":
            return StickyStyle.displaySymbolName
        default:
            break
        }
        if lua.hasPrefix("KiwiDesk.switch_layer(") {
            return "square.3.layers.3d"
        }
        // KiwiVision wears its Settings card's symbol (#2103).
        if lua.hasPrefix("kiwivision.toggle(") {
            return SettingsDestination.kiwiVision.symbol
        }
        guard lua.hasPrefix("KiwiDesk.resize(") else { return nil }
        let shrinks = lua.contains("-")
        if lua.contains("\"x\"") {
            return shrinks
                ? "arrow.right.and.line.vertical.and.arrow.left"
                : "arrow.left.and.line.vertical.and.arrow.right"
        }
        if lua.contains("\"y\"") {
            return shrinks
                ? "arrow.down.and.line.horizontal.and.arrow.up"
                : "arrow.up.and.line.horizontal.and.arrow.down"
        }
        return nil
    }

    /// The symbols the Shortcuts side draws beyond `verbIcon`'s
    /// Core marks — its own literals, Custom's Lua mark and the
    /// gather badge — for the resolve guard.
    static let verbSymbols = [
        "rectangle.righthalf.inset.filled.arrow.right",
        "rectangle.lefthalf.inset.filled.arrow.left",
        "square.3.layers.3d",
        "arrow.right.and.line.vertical.and.arrow.left",
        "arrow.left.and.line.vertical.and.arrow.right",
        "arrow.down.and.line.horizontal.and.arrow.up",
        "arrow.up.and.line.horizontal.and.arrow.down",
        "curlybraces",
        "rectangle.stack",
    ]

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
