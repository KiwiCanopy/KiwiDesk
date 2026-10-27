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
            ?? directionIcons[cmd.lua]
            ?? spaceFallbackIcon(for: cmd.lua)
            ?? verbIcon(for: cmd.lua)
    }

    /// The focus and swap rows' glyphs, keyed on the catalog's own
    /// commands (#2529 ▸ Ruling): each wears its one direction, focus
    /// a line arrow, swap a filled triangle, so a one-sided line
    /// arrow always means a focus move.
    static let directionIcons: [String: String] = {
        let names = KeybindingCatalog.directionNames
        let focus = zip(KeybindingCatalog.focusDirections, names).map {
            ($0.lua, "arrow.\($1)")
        }
        let swap = zip(KeybindingCatalog.swapDirections, names).map {
            ($0.lua, "arrowtriangle.\($1).fill")
        }
        return Dictionary(uniqueKeysWithValues: focus + swap)
    }()

    /// The glyph a folded set wears in place of its first member's:
    /// every direction the set covers, never one (#2529 ▸ Ruling).
    /// Nil keeps the first member's, for sets whose members share
    /// one glyph or show both ways already.
    static func foldIcon(for family: ShortcutFold.Family) -> String? {
        switch family {
        case .goToSpace, .moveToSpace, .moveToSpaceFollow:
            return spaceGroupIcon
        case .focusDirections:
            return "arrow.up.and.down.and.arrow.left.and.right"
        case .swapDirections: return "dpad.fill"
        case .layoutCycle: return layoutCycle.drawn
        case .goToDesktop, .moveToDesktop, .moveToDesktopFollow,
            .spaceStep, .spaceHistory, .width, .height:
            return nil
        }
    }

    /// A symbol newer than the deployment floor, and the older one
    /// the floor's macOS draws instead (`ShortcutSymbolFloorTests`).
    struct FloorSymbol: Sendable {
        let name: String
        let floor: String
        /// The macOS `name` needs, the `#available` below.
        static let since = 15

        var drawn: String {
            if #available(macOS 15, *) { return name }
            return floor
        }
    }

    /// The layout cycle's arrows (#2529 ▸ Ruling).
    static let nextLayout = FloorSymbol(
        name: "arrow.trianglehead.clockwise",
        floor: "arrow.clockwise.circle"
    )
    static let previousLayout = FloorSymbol(
        name: "arrow.trianglehead.counterclockwise",
        floor: "arrow.counterclockwise.circle"
    )
    static let layoutCycle = FloorSymbol(
        name: "arrow.trianglehead.2.clockwise",
        floor: "arrow.triangle.2.circlepath"
    )
    static let floorSymbols = [nextLayout, previousLayout, layoutCycle]

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
    /// card's symbol (#2103). Read through `icon(for:)`, which the
    /// Settings rows draw from too (#2670).
    static func verbIcon(for lua: String) -> String? {
        switch lua {
        case "KiwiDesk.cycle_mode()":
            return nextLayout.drawn
        case "KiwiDesk.cycle_mode(\"prev\")":
            return previousLayout.drawn
        case "KiwiDesk.toggle_floating()":
            return FloatingStyle.symbolName
        case "KiwiDesk.toggle_sticky()":
            return StickyStyle.symbolName
        case "KiwiDesk.toggle_display_sticky()":
            return StickyStyle.displaySymbolName
        // The row draws the pocket mark; this is its stand-in
        // where a surface draws symbols only (#2446).
        case "KiwiDesk.pocket()":
            return "tray.and.arrow.down.fill"
        case "KiwiDesk.reset_layout_sizing()":
            return "arrow.counterclockwise"
        // Two screens: back to the one before (#2512).
        case KeybindingCatalog.screenLastRow.lua:
            return "display.2"
        // Owner ruling on #2448.
        case "KiwiDesk.toggle_maximized()":
            return "arrow.up.left.and.arrow.down.right"
        // The bars' show/hide (#2530): the Space Bar wears the arrowed
        // symbol the 3.2.0 notes' hiding-bars spotlight wears, the App
        // Bar the strip along the screen's foot (owner, 2026-10-23).
        case KeybindingCatalog.toggleSpaceBar.lua:
            return "menubar.arrow.up.rectangle"
        case KeybindingCatalog.toggleAppBar.lua:
            return "dock.rectangle"
        // Track's own verbs: to the line before or after, a swap
        // of two tracks (#2530).
        case KeybindingCatalog.moveToTrackRows[0].lua:
            return "arrow.backward.to.line"
        case KeybindingCatalog.moveToTrackRows[1].lua:
            return "arrow.forward.to.line"
        case KeybindingCatalog.trackSwapRows[0].lua,
            KeybindingCatalog.trackSwapRows[1].lua:
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

    /// The symbols the Shortcuts side draws on no command row —
    /// Custom's Lua mark and the gather badge — for the resolve
    /// guard; a command row's symbol is resolved from the rows
    /// themselves (`ShortcutRowSymbolTests`).
    static let verbSymbols = [
        LuaMark.symbol,
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
