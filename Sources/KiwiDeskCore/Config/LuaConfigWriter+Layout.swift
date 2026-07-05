import Foundation

/// Per-layout parameter setters and the keybinding block.
extension LuaConfigWriter {
    static func layoutParams(
        _ settings: TilingSettings
    ) -> String {
        [
            bsp(settings.bsp),
            stack(settings.stack),
            scroll(settings.scrolling),
            grid(settings.grid),
            monocle(settings.monocle),
        ]
        .joined(separator: "\n")
    }

    private static func bsp(_ params: BspParams) -> String {
        [
            "bsp.set_strategy("
                + LuaLiteral.string(params.strategy.rawValue) + ")",
            "bsp.set_ratio("
                + LuaLiteral.number(params.splitRatio) + ")",
            "bsp.set_new_window_placement("
                + LuaLiteral.string(
                    params.newWindowPlacement.rawValue
                ) + ")",
        ].joined(separator: "\n")
    }

    private static func stack(_ params: StackParams) -> String {
        [
            "stack.set_master_count("
                + String(params.masterCount) + ")",
            "stack.set_master_ratio("
                + LuaLiteral.number(params.masterRatio) + ")",
            "stack.set_overflow_style("
                + LuaLiteral.string(
                    params.overflowStyle.rawValue
                ) + ")",
            "stack.set_new_window_placement("
                + LuaLiteral.string(
                    params.newWindowPlacement.rawValue
                ) + ")",
        ].joined(separator: "\n")
    }

    /// `slot_size` emits as the Lua setter accepts it: `0` for
    /// auto, a number for points, a `"NN%"` string for a fraction.
    private static func slotSizeLiteral(
        _ size: ScrollSize
    ) -> String {
        switch size {
        case .auto:
            return "0"
        case .points(let points):
            return LuaLiteral.number(points)
        case .fraction(let fraction):
            return LuaLiteral.string(
                ScrollSize.percentString(fraction)
            )
        }
    }

    private static func scroll(
        _ params: ScrollingParams
    ) -> String {
        [
            "scroll.set_slot_size("
                + slotSizeLiteral(params.slotSize) + ")",
            "scroll.set_anchor("
                + LuaLiteral.string(params.anchor.rawValue) + ")",
            "scroll.set_orientation("
                + LuaLiteral.string(params.orientation.rawValue)
                + ")",
            "scroll.set_new_window_placement("
                + LuaLiteral.string(
                    params.newWindowPlacement.rawValue
                ) + ")",
            layoutBar("scroll", params.appBar),
        ].joined(separator: "\n")
    }

    private static func grid(_ params: GridParams) -> String {
        [
            "grid.set_type("
                + LuaLiteral.string(params.type.rawValue) + ")",
            "grid.set_fill_empty_space("
                + LuaLiteral.bool(params.fillEmptySpace) + ")",
            "grid.set_split_direction("
                + LuaLiteral.string(
                    params.splitDirection.rawValue
                ) + ")",
            "grid.set_dimensions(" + String(params.columns)
                + ", " + String(params.rows) + ")",
            "grid.set_new_window_placement("
                + LuaLiteral.string(
                    params.newWindowPlacement.rawValue
                ) + ")",
        ].joined(separator: "\n")
    }

    // MARK: - Keybindings

    static func keybindings(_ modes: [KeyMode]) -> String {
        var blocks: [String] = []
        for mode in modes {
            let rows = mode.bindings.filter {
                !$0.combo.isEmpty
            }
            if mode.isDefault {
                blocks.append(defaultBinds(rows))
            } else {
                blocks.append(defineMode(mode, rows: rows))
            }
        }
        return
            blocks
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    /// The default mode always shows the standard menu bar
    /// glyph — the GUI never offers an icon picker for it (see
    /// `KeybindingsTab.modeIconRow`), so `KiwiDesk.bind` has no
    /// icon argument to emit. Any icon on the default mode
    /// (e.g. from hand-edited profile JSON) is silently dropped
    /// here rather than surfaced: revisit both sides together
    /// if the GUI ever allows a default-mode icon.
    private static func defaultBinds(
        _ rows: [KeyBinding]
    ) -> String {
        rows.map { row in
            "KiwiDesk.bind("
                + LuaLiteral.string(row.combo)
                + ", function()\n" + indent(row.lua)
                + "\nend)"
        }
        .joined(separator: "\n")
    }

    private static func defineMode(
        _ mode: KeyMode,
        rows: [KeyBinding]
    ) -> String {
        var lines = [
            "KiwiDesk.define_mode("
                + LuaLiteral.string(mode.name) + ", {"
        ]
        for row in rows {
            lines.append(
                "    [" + LuaLiteral.string(row.combo)
                    + "] = function()\n"
                    + indent(row.lua, level: 2)
                    + "\n    end,"
            )
        }
        if let icon = mode.icon, !icon.isEmpty {
            lines.append(
                "}, { icon = " + LuaLiteral.string(icon) + " })"
            )
        } else {
            lines.append("})")
        }
        return lines.joined(separator: "\n")
    }

    /// Indents a (possibly multi-line) Lua body.
    private static func indent(
        _ body: String,
        level: Int = 1
    ) -> String {
        let pad = String(repeating: "    ", count: level)
        return
            body
            .components(separatedBy: "\n")
            .map { pad + $0 }
            .joined(separator: "\n")
    }
}
