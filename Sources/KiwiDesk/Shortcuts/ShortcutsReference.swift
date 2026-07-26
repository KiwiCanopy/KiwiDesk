import Foundation
import KiwiDeskCore

/// One row in the read-only shortcuts reference: a label, the
/// rendered key-combo glyph string, and an optional leading glyph
/// (a space icon) or app bundle id (a real app icon). Pure value
/// data — the view owns all presentation.
struct ShortcutRow: Identifiable {
    let id: String
    let label: String
    /// The combo rendered as native glyphs (`⌃⌥←`), through the
    /// same `ComboSymbols` path the editor uses.
    let combo: String
    /// Leading SF Symbol / emoji glyph (space rows). Nil = none.
    var icon: String? = nil
    /// App bundle id for a real 20pt icon (Apps band). Nil = none.
    var bundleID: String? = nil
    /// App Font ligature (#294): set when the bar's icon source
    /// is Glyphs and this app has one, so the panel's Apps band
    /// matches the bar. Wins over `bundleID`; nil falls back to
    /// the bundle icon.
    var glyph: String? = nil
    /// Custom-Lua rows render their label monospaced.
    var monospaced: Bool = false
    /// Trailing accessory glyph for a non-default launch behavior
    /// (#334: Open New). Nil = default row, which renders exactly
    /// as before. `accessoryHelp` is its hover tooltip.
    var accessoryIcon: String? = nil
    var accessoryHelp: String = ""
}

/// A named group of rows inside the Controls band (Focus / Move
/// Windows / Size & float / Switch modes).
struct ShortcutSubgroup: Identifiable {
    let title: String
    let rows: [ShortcutRow]
    var id: String { title }
}

/// The whole read-only reference for one key mode: three bands
/// (Controls grouped by subgroup, Apps, Custom). Empty bands are
/// dropped by the builder, so an empty band never renders.
struct ShortcutsReference {
    // `var`, not `let`: post-processing (the #294 glyph pass)
    // mutates a copy instead of re-initializing memberwise,
    // which would be one more hand-mirrored field list.
    var modeName: String
    var controls: [ShortcutSubgroup]
    var apps: [ShortcutRow]
    var custom: [ShortcutRow]

    /// True when the active mode has no bound shortcuts at all —
    /// the view shows a "nothing bound yet" placeholder.
    var isEmpty: Bool {
        controls.isEmpty && apps.isEmpty && custom.isEmpty
    }
}

/// Builds a `ShortcutsReference` from a live key mode by filtering
/// the `KeybindingCatalog` presets to the bindings that actually
/// exist — reusing the exact labels, icons, and Lua identity the
/// editor authors, so the panel can never disagree with the tab.
/// Anything bound but unrecognized (custom Lua, or a resize of a
/// non-current step) falls through to the Custom band, so no bound
/// shortcut is ever invisible.
@MainActor
enum ShortcutsReferenceBuilder {
    static func build(
        mode: KeyMode,
        spaces: [SpaceID],
        spaceIcons: [SpaceID: String],
        resizeStep: Int,
        modeNames: [String]
    ) -> ShortcutsReference {
        // Keyed by row identity (UUID), not `lua`: two bindings can
        // share a command's Lua with different combos (vim keys +
        // arrows both bound to `focus("left")`). Keying by `lua`
        // would consume the whole command on the first match and
        // drop the second from every band — invisible, breaking the
        // "never drop a bound shortcut" contract. By id, only the
        // matched row is consumed; the twin falls through to Custom.
        var consumed = Set<UUID>()

        // A bound binding (non-empty combo) for a preset's Lua.
        func bound(_ lua: String) -> KeyBinding? {
            mode.bindings.first {
                $0.lua == lua && !$0.combo.isEmpty
            }
        }

        func rows(_ commands: [NavCommand]) -> [ShortcutRow] {
            commands.compactMap { cmd in
                guard let binding = bound(cmd.lua) else {
                    return nil
                }
                consumed.insert(binding.id)
                // Custom space icon first, then a directional arrow
                // for compass commands, then a space fallback so a
                // space row always carries a glyph even when the user
                // set no icon for it.
                let icon =
                    cmd.icon.flatMap { $0.isEmpty ? nil : $0 }
                    ?? directionalIcon(for: cmd.lua)
                    ?? spaceFallbackIcon(for: cmd.lua)
                return ShortcutRow(
                    id: cmd.lua,
                    label: cmd.resolvedLabel,
                    combo: glyphs(binding.combo),
                    icon: icon
                )
            }
        }

        let controls = buildControls(
            activeMode: mode.name,
            spaces: spaces,
            spaceIcons: spaceIcons,
            resizeStep: resizeStep,
            modeNames: modeNames,
            rows: rows
        )
        let apps = buildApps(mode, consumed: &consumed)
        let custom = buildCustom(mode, consumed: consumed)

        return ShortcutsReference(
            modeName: mode.name,
            controls: controls,
            apps: apps,
            custom: custom
        )
    }

    // MARK: - Bands

    /// Membership twin of the editor's `FocusGroup` /
    /// `MoveWindowsGroup` / `SizeFloatGroup` / `ChangeModesGroup`
    /// (`KeybindingGroups.swift`) and `KeybindingCatalog`'s
    /// `navigationGroups`. Row identity (label / icon / Lua) is
    /// single-sourced from the catalog, so only the *grouping* is
    /// mirrored here — and a forgotten command degrades to Custom via
    /// the fallthrough, never vanishes. Keep the three in step.
    private static func buildControls(
        activeMode: String,
        spaces: [SpaceID],
        spaceIcons: [SpaceID: String],
        resizeStep: Int,
        modeNames: [String],
        rows: ([NavCommand]) -> [ShortcutRow]
    ) -> [ShortcutSubgroup] {
        let focus =
            KeybindingCatalog.focusDirections
            + KeybindingCatalog.goToSpace(spaces, icons: spaceIcons)
        let move =
            KeybindingCatalog.swapDirections
            + KeybindingCatalog.moveToTrackRows
            + KeybindingCatalog.trackSwapRows
            + KeybindingCatalog.moveToSpace(
                spaces,
                icons: spaceIcons
            )
        // Exclude the active mode: you never switch to the mode
        // you're already in, and the editor's ChangeModesGroup
        // filters it out the same way — keep the two in parity.
        let switchModes =
            modeNames
            .filter { $0 != activeMode }
            .map { KeybindingCatalog.switchModeCommand($0) }
        return [
            ShortcutSubgroup(
                title: L("shortcuts.section.focus", "Focus"),
                rows: rows(focus)
            ),
            ShortcutSubgroup(
                title: L(
                    "shortcuts.section.move_windows",
                    "Move windows"
                ),
                rows: rows(move)
            ),
            ShortcutSubgroup(
                title: L(
                    "shortcuts.section.size_float",
                    "Size & float"
                ),
                rows: rows(
                    KeybindingCatalog.resizeAndFloat(
                        step: resizeStep
                    )
                )
            ),
            ShortcutSubgroup(
                title: L(
                    "shortcuts.section.switch_modes",
                    "Switch modes"
                ),
                rows: rows(switchModes)
            ),
        ].filter { !$0.rows.isEmpty }
    }

    private static func buildApps(
        _ mode: KeyMode,
        consumed: inout Set<UUID>
    ) -> [ShortcutRow] {
        mode.bindings
            .filter {
                $0.kind == .application && !$0.combo.isEmpty
            }
            .map { binding -> ShortcutRow in
                consumed.insert(binding.id)
                let bundleID = KeybindingCatalog.appBundleID(
                    from: binding.lua
                )
                let name =
                    bundleID.map {
                        KeybindingCatalog.displayName(
                            forBundleID: $0
                        )
                    } ?? binding.label
                // A trailing badge marks a non-default (Open New)
                // launch behavior; default rows carry none, so they
                // render identically to before (#334).
                let openNew =
                    KeybindingCatalog.appLaunchBehavior(
                        from: binding.lua
                    ) == .openNew
                return ShortcutRow(
                    id: binding.id.uuidString,
                    label: name,
                    combo: glyphs(binding.combo),
                    bundleID: bundleID,
                    accessoryIcon: openNew
                        ? "macwindow.badge.plus" : nil,
                    accessoryHelp: openNew
                        ? L(
                            "shortcuts.app_behavior.open_new.badge",
                            "Opens a new instance"
                        )
                        : ""
                )
            }
            .sorted { lhs, rhs in
                let order = lhs.label
                    .localizedCaseInsensitiveCompare(rhs.label)
                // Two rows for the same app (Open or Focus + Open
                // New) share a label; the id tiebreaker pins their
                // order, matching the editor's `recomputeOrder`.
                if order == .orderedSame { return lhs.id < rhs.id }
                return order == .orderedAscending
            }
    }

    private static func buildCustom(
        _ mode: KeyMode,
        consumed: Set<UUID>
    ) -> [ShortcutRow] {
        mode.bindings
            .filter {
                !$0.combo.isEmpty && !consumed.contains($0.id)
            }
            .map { binding in
                ShortcutRow(
                    id: binding.id.uuidString,
                    label: binding.lua,
                    combo: glyphs(binding.combo),
                    monospaced: true
                )
            }
    }

    /// A directional SF Symbol for a compass-direction command
    /// (`focus`/`swap` left/right/up/down) — the one clearly-spatial
    /// glyph the hybrid symbol scheme adds beyond space/app icons.
    /// Non-spatial commands (prev/next track, resize axes,
    /// switch-mode, custom Lua) stay label-only by design. Panel-only:
    /// the shared catalog and the editor rows are untouched.
    private static func directionalIcon(for lua: String) -> String? {
        // A space or mode literally named a direction word would
        // otherwise false-match on the substring — those commands own
        // their own glyphs (space fallback / none), so bail first.
        guard !lua.contains("_space"),
            !lua.contains("switch_mode")
        else { return nil }
        if lua.contains("\"left\"") { return "arrow.left" }
        if lua.contains("\"right\"") { return "arrow.right" }
        if lua.contains("\"up\"") { return "arrow.up" }
        if lua.contains("\"down\"") { return "arrow.down" }
        return nil
    }

    /// A fallback glyph for a space command whose space has no
    /// custom icon: the space number in a square (`3.square`) — a
    /// space-shaped symbol carrying the number, matching how the row
    /// reads ("Go to Space 3"). Deliberately NOT the Space Bar's
    /// plain-digit fallback: this is a symbol slot in a list row
    /// with no boxed wrapper, so the bar's box-in-a-box problem
    /// (QA 2026-07-19) doesn't apply. Non-numeric space ids get the
    /// generic Spaces glyph. Nil for non-space commands.
    private static func spaceFallbackIcon(
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

    /// The first double-quoted argument in a Lua call, e.g. `"3"`
    /// from `KiwiDesk.focus_space("3")`.
    private static func quotedArg(in lua: String) -> String? {
        guard let open = lua.range(of: "(\"") else { return nil }
        let rest = lua[open.upperBound...]
        guard let close = rest.range(of: "\"") else { return nil }
        return String(rest[..<close.lowerBound])
    }

    /// The combo string rendered as native glyphs via the same
    /// `ComboSymbols` + layout path the editor uses — so a combo
    /// is pixel-identical across the two surfaces. A parse failure
    /// falls back to the raw stored string.
    private static func glyphs(_ combo: String) -> String {
        guard let parsed = KeyCombo.parse(combo) else {
            return combo
        }
        return ComboSymbols.render(
            parsed,
            layoutChar: LayoutKeyGlyph.char
        )
    }
}
