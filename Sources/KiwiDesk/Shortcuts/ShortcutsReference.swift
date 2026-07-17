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
    /// Custom-Lua rows render their label monospaced.
    var monospaced: Bool = false
}

/// A named group of rows inside the Controls band (Focus / Move
/// Windows / Size & Float / Switch modes).
struct ShortcutSubgroup: Identifiable {
    let title: String
    let rows: [ShortcutRow]
    var id: String { title }
}

/// The whole read-only reference for one key mode: three bands
/// (Controls grouped by subgroup, Apps, Custom). Empty bands are
/// dropped by the builder, so an empty band never renders.
struct ShortcutsReference {
    let modeName: String
    let controls: [ShortcutSubgroup]
    let apps: [ShortcutRow]
    let custom: [ShortcutRow]

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
        var consumed = Set<String>()

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
                consumed.insert(binding.lua)
                return ShortcutRow(
                    id: cmd.lua,
                    label: cmd.resolvedLabel,
                    combo: glyphs(binding.combo),
                    icon: cmd.icon
                )
            }
        }

        let controls = buildControls(
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

    private static func buildControls(
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
        let switchModes = modeNames.map {
            KeybindingCatalog.switchModeCommand($0)
        }
        return [
            ShortcutSubgroup(
                title: L("shortcuts.section.focus", "Focus"),
                rows: rows(focus)
            ),
            ShortcutSubgroup(
                title: L(
                    "shortcuts.section.move_windows",
                    "Move Windows"
                ),
                rows: rows(move)
            ),
            ShortcutSubgroup(
                title: L(
                    "shortcuts.section.size_float",
                    "Size & Float"
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
        consumed: inout Set<String>
    ) -> [ShortcutRow] {
        mode.bindings
            .filter {
                $0.kind == .application && !$0.combo.isEmpty
            }
            .map { binding -> ShortcutRow in
                consumed.insert(binding.lua)
                let bundleID = KeybindingCatalog.appBundleID(
                    from: binding.lua
                )
                let name =
                    bundleID.map {
                        KeybindingCatalog.displayName(
                            forBundleID: $0
                        )
                    } ?? binding.label
                return ShortcutRow(
                    id: binding.id.uuidString,
                    label: name,
                    combo: glyphs(binding.combo),
                    bundleID: bundleID
                )
            }
            .sorted {
                $0.label.localizedCaseInsensitiveCompare($1.label)
                    == .orderedAscending
            }
    }

    private static func buildCustom(
        _ mode: KeyMode,
        consumed: Set<String>
    ) -> [ShortcutRow] {
        mode.bindings
            .filter {
                !$0.combo.isEmpty && !consumed.contains($0.lua)
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
