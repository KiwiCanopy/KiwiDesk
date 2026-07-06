import Foundation

/// Generates the `init.lua` managed block from a `GuiConfig`.
///
/// The inverse of the Lua API: every setting becomes the exact
/// `KiwiDesk.*` / `bsp.*` / … call the config loader already
/// understands, so writing then reloading reproduces the same
/// live state (verified by the round-trip test). Output is
/// deterministic (sorted keys) so the file only changes when a
/// setting does.
public enum LuaConfigWriter {
    /// The full managed-block body (no marker lines).
    public static func block(for config: GuiConfig) -> String {
        var sections: [String] = []
        sections.append(gaps(config.settings))
        sections.append(
            placementOverrideCalls(config.settings)
        )
        sections.append(
            "KiwiDesk.set_min_window_size("
                + LuaLiteral.number(
                    config.settings.minWindowSize
                ) + ")"
        )
        sections.append(spaceModes(config.spaceModes))
        sections.append(appBarStyle(config.settings.appBarStyle))
        sections.append(layoutParams(config.settings))
        sections.append(dragVisuals(config.settings))
        sections.append(mouseResize(config.settings))
        sections.append(animations(config.settings))
        sections.append(appRules(config.appRules))
        sections.append(
            spaceMonitorMap(config.spaceMonitorMap)
        )
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

    // MARK: - Gaps

    static func gaps(_ settings: TilingSettings) -> String {
        var lines = [gapCall("set_gap_global", settings.gapsGlobal)]
        for space in settings.gapsOverride.keys.sorted(by: {
            $0.raw < $1.raw
        }) {
            guard let gaps = settings.gapsOverride[space] else {
                continue
            }
            lines.append(
                "KiwiDesk.set_gap_override("
                    + LuaLiteral.space(space) + ", "
                    + gapTable(gaps) + ")"
            )
        }
        return lines.joined(separator: "\n")
    }

    /// `set_gap_global(n)` when all six gaps match; otherwise
    /// the per-edge table form.
    private static func gapCall(
        _ name: String,
        _ gaps: Gaps
    ) -> String {
        "KiwiDesk.\(name)(\(gapArgument(gaps)))"
    }

    private static func gapArgument(_ gaps: Gaps) -> String {
        let values = [
            gaps.outer.top, gaps.outer.bottom,
            gaps.outer.left, gaps.outer.right,
            gaps.inner.horizontal, gaps.inner.vertical,
        ]
        if let first = values.first,
            values.allSatisfy({ $0 == first })
        {
            return LuaLiteral.number(first)
        }
        return gapTable(gaps)
    }

    private static func gapTable(_ gaps: Gaps) -> String {
        "{ top = " + LuaLiteral.number(gaps.outer.top)
            + ", bottom = " + LuaLiteral.number(gaps.outer.bottom)
            + ", left = " + LuaLiteral.number(gaps.outer.left)
            + ", right = " + LuaLiteral.number(gaps.outer.right)
            + ", inner_horizontal = "
            + LuaLiteral.number(gaps.inner.horizontal)
            + ", inner_vertical = "
            + LuaLiteral.number(gaps.inner.vertical) + " }"
    }

    // MARK: - Modes and rules

    static func spaceModes(
        _ modes: [SpaceID: LayoutMode]
    ) -> String {
        modes.keys.sorted { $0.raw < $1.raw }
            .compactMap { space in
                modes[space].map { mode in
                    "KiwiDesk.set_mode("
                        + LuaLiteral.space(space) + ", "
                        + LuaLiteral.string(mode.rawValue) + ")"
                }
            }
            .joined(separator: "\n")
    }

    static func appRules(_ rules: [String: SpaceID]) -> String {
        guard !rules.isEmpty else { return "" }
        var lines = ["app_rules = {"]
        for app in rules.keys.sorted() {
            guard let space = rules[app] else { continue }
            lines.append(
                "    [" + LuaLiteral.string(app) + "] = "
                    + LuaLiteral.string(space.raw) + ","
            )
        }
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    /// `space_monitor_map = { ["1"] = { "fp" }, … }`. String
    /// keys (read back as `SpaceID`); each value a fingerprint
    /// chain. Empty chains and an empty map are omitted.
    static func spaceMonitorMap(
        _ map: [SpaceID: [String]]
    ) -> String {
        let entries = map.keys.sorted { $0.raw < $1.raw }
            .compactMap { space -> String? in
                guard let chain = map[space], !chain.isEmpty
                else { return nil }
                let items =
                    chain
                    .map { LuaLiteral.string($0) }
                    .joined(separator: ", ")
                return "    [" + LuaLiteral.string(space.raw)
                    + "] = { " + items + " },"
            }
        guard !entries.isEmpty else { return "" }
        return (["space_monitor_map = {"] + entries + ["}"])
            .joined(separator: "\n")
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

    /// One `set_new_window_placement_override` call per space
    /// override; empty when there are none.
    private static func placementOverrideCalls(
        _ settings: TilingSettings
    ) -> String {
        let overrides = settings.placementOverride
        guard !overrides.isEmpty else { return "" }
        return
            overrides.keys.sorted { $0.raw < $1.raw }
            .compactMap { space in
                overrides[space].map { placement in
                    "KiwiDesk.set_new_window_placement_override("
                        + LuaLiteral.space(space) + ", "
                        + LuaLiteral.string(placement.rawValue)
                        + ")"
                }
            }
            .joined(separator: "\n")
    }

    /// `set_mouse_resize` (issue #12). Sleep/wake restore
    /// (`enable_wake_restore`, `set_wake_restore_delay`) is
    /// deliberately not emitted — it's an advanced knob left to
    /// hand-written `init.lua`.
    static func mouseResize(_ settings: TilingSettings) -> String {
        "KiwiDesk.set_mouse_resize("
            + LuaLiteral.string(settings.mouseResize.rawValue)
            + ")"
    }

    /// The per-trigger `animations.*` toggles (issue #11/#12).
    static func animations(_ settings: TilingSettings) -> String {
        let anims = settings.animations
        return [
            "animations.set_on_space_change("
                + LuaLiteral.bool(anims.onSpaceChange) + ")",
            "animations.set_on_scrolling("
                + LuaLiteral.bool(anims.onScrolling) + ")",
            "animations.set_on_window_resize("
                + LuaLiteral.bool(anims.onWindowResize) + ")",
            "animations.set_on_window_swap("
                + LuaLiteral.bool(anims.onWindowSwap) + ")",
            "animations.set_on_relayout("
                + LuaLiteral.bool(anims.onRelayout) + ")",
        ].joined(separator: "\n")
    }
}
