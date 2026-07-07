import Foundation

/// Generates the `init.lua` managed block from a `GuiConfig`.
///
/// Since the config split (#36), `init.lua` only carries the
/// global, non-profile declarations: keybindings, app rules,
/// float rules, and native-Space profile bindings. All tiling
/// state (gaps, layout params, space modes, monitor pins) lives
/// in the profile JSON instead — the Lua tiling API stays valid
/// for hand-written configs as base state, but the GUI no
/// longer generates those calls. Output is deterministic
/// (sorted keys) so the file only changes when a setting does.
public enum LuaConfigWriter {
    /// The full managed-block body (no marker lines).
    public static func block(for config: GuiConfig) -> String {
        var sections: [String] = []
        sections.append(appRules(config.appRules))
        sections.append(floatRules(config.floatRules))
        sections.append(
            profileBindings(config.profileBindings)
        )
        sections.append(keybindings(config.modes))
        return
            sections
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    // MARK: - Rules

    static func appRules(_ rules: [String: SpaceID]) -> String {
        guard !rules.isEmpty else { return "" }
        var lines = ["app_rules = {"]
        for app in rules.keys.sorted() {
            guard let space = rules[app] else { continue }
            lines.append(
                "    [" + LuaLiteral.string(app) + "] = "
                    + SpaceLuaArg.quote(space.raw) + ","
            )
        }
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    static func floatRules(_ rules: [String]) -> String {
        guard !rules.isEmpty else { return "" }
        let items = rules.sorted()
            .map { LuaLiteral.string($0) }
            .joined(separator: ", ")
        return "float_rules = { " + items + " }"
    }

    static func profileBindings(
        _ bindings: [Int: String]
    ) -> String {
        bindings.keys.sorted()
            .compactMap { number in
                bindings[number].map { name in
                    "KiwiDesk.bind_profile_to_native_space("
                        + String(number) + ", "
                        + LuaLiteral.string(name) + ")"
                }
            }
            .joined(separator: "\n")
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
