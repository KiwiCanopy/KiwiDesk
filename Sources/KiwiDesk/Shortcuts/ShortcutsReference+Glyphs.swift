import Foundation
import KiwiDeskCore

/// Shortcut reference row glyphs and combo string formatting
/// (`ShortcutsReferenceBuilder`, #820).
extension ShortcutsReferenceBuilder {
    /// A row's glyph: the command's own, else its direction, its
    /// Space, or its verb. Every row the panel draws resolves to
    /// one (#2530, `ShortcutRowSymbolTests`).
    static func icon(for cmd: NavCommand) -> String? {
        cmd.icon.flatMap { $0.isEmpty ? nil : $0 }
            ?? directionalIcon(for: cmd.lua)
            ?? spaceFallbackIcon(for: cmd.lua)
            ?? verbIcon(for: cmd.lua)
    }

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
        return spaceGroupIcon
    }

    /// The Spaces glyph a row naming no one Space wears.
    static let spaceGroupIcon = "squares.below.rectangle"

    /// A verb row's glyph on the key panel's Shortcuts side
    /// (#2246): the layout cycle, the size quartet and its reset
    /// (#2303), the float and
    /// sticky toggles — wearing the marks the windows wear — a
    /// layer switch, and the KiwiVision toggle wearing its Settings
    /// card's symbol (#2103). Panel-only; Settings draws glyphs only
    /// where one names a thing.
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
        case "KiwiDesk.reset_layout_sizing()":
            return "arrow.counterclockwise"
        // Owner ruling on #2448.
        case "KiwiDesk.toggle_maximized()":
            return "arrow.up.left.and.arrow.down.right"
        // The bars' show/hide (#2530): the Space Bar wears Settings'
        // Bars symbol, the App Bar the strip along the screen's foot.
        case KeybindingCatalog.toggleSpaceBar.lua:
            return SettingsDestination.bars.symbol
        case KeybindingCatalog.toggleAppBar.lua:
            return "dock.rectangle"
        // Track's own verbs: to the line before or after, a swap
        // of two tracks (#2530).
        case "KiwiDesk.move_to_track(\"prev\")":
            return "arrow.backward.to.line"
        case "KiwiDesk.move_to_track(\"next\")":
            return "arrow.forward.to.line"
        case "track.swap(\"prev\")", "track.swap(\"next\")":
            return "rectangle.2.swap"
        default:
            break
        }
        if lua.hasPrefix("KiwiDesk.switch_layer(") {
            return "square.3.layers.3d"
        }
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
        "arrow.counterclockwise",
        "arrow.up.left.and.arrow.down.right",
        "dock.rectangle",
        "arrow.backward.to.line",
        "arrow.forward.to.line",
        "rectangle.2.swap",
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
