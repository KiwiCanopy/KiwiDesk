import Foundation
import KiwiDeskCore

/// Builds a `ShortcutsReference` from a live key layer by filtering
/// the `KeybindingCatalog` presets to the bindings that actually
/// exist — reusing the exact labels, icons, and Lua identity the
/// editor authors, so the panel can never disagree with the tab.
/// Anything bound but unrecognized (custom Lua, or a resize of a
/// non-current step) falls through to the Custom band, so no bound
/// shortcut is ever invisible — with one deliberate exception:
/// `KiwiDesk.show_shortcuts()` opens this very panel, so it is
/// dropped from the working set before any band builds and never
/// becomes a row in any of them. The footer's dismiss hint
/// teaches its combo in every state whose bindings are live
/// (paused bindings do nothing, so the generic hint is honest
/// there). Un-suppressing it would re-leak the seeded ⌃⌥K
/// default (#602) into Custom as raw Lua — the band that means
/// "user-authored". `ShortcutsSelfRowTests` pins the exception.
@MainActor
enum ShortcutsReferenceBuilder {
    static func build(
        layer: KeyLayer,
        spaces: [SpaceID],
        spaceIcons: [SpaceID: String],
        resizeStep: Int,
        layerNames: [String]
    ) -> ShortcutsReference {
        // The panel's own opener never renders as a row (see the
        // type docstring): drop every binding of it — whatever its
        // kind or combo — from the working set before any band
        // builds, so the suppression holds across all three bands
        // by construction, not by each band's filter remembering.
        var layer = layer
        layer.bindings.removeAll {
            $0.lua == ShortcutsOpenBinding.lua
        }

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
            layer.bindings.first {
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
            activeLayer: layer.name,
            spaces: spaces,
            spaceIcons: spaceIcons,
            resizeStep: resizeStep,
            layerNames: layerNames,
            rows: rows
        )
        let apps = buildApps(layer, consumed: &consumed)
        let custom = buildCustom(layer, consumed: consumed)

        return ShortcutsReference(
            layerName: layer.name,
            controls: controls,
            apps: apps,
            custom: custom
        )
    }

    // MARK: - Bands

    /// Membership twin of the editor's grouping. Row identity
    /// (label / icon / Lua) is single-sourced from
    /// `KeybindingCatalog`, so only the *grouping* is mirrored
    /// here — and a forgotten command degrades to Custom via the
    /// fallthrough, never vanishes.
    ///
    /// Since #678 Phase 3 the editor's grouping has an OWNER —
    /// the settings census, read through `ShortcutsRowOrder` and
    /// expanded by `ShortcutsFamilyRows` — and this builder is
    /// now the copy rather than a peer. It still reads the
    /// catalog directly, which is why the panel and the editor
    /// can disagree about ORDER (they did, over the per-space
    /// move pair) even while agreeing about membership.
    ///
    /// **A family added to the census owes this builder a band
    /// too**, until it consumes the expander. Consuming it is the
    /// real fix and is available — this is `@MainActor` and
    /// GUI-side — but it is a behavioural change to the panel and
    /// belongs in its own change, not in the one that created the
    /// owner.
    private static func buildControls(
        activeLayer: String,
        spaces: [SpaceID],
        spaceIcons: [SpaceID: String],
        resizeStep: Int,
        layerNames: [String],
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
        // Exclude the active layer: you never switch to the layer
        // you're already in, and the editor's SwitchLayersGroup
        // filters it out the same way — keep the two in parity.
        let switchLayers =
            layerNames
            .filter { $0 != activeLayer }
            .map { KeybindingCatalog.switchLayerCommand($0) }
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
                    "shortcuts.section.switch_layers",
                    "Switch layers"
                ),
                rows: rows(switchLayers)
            ),
        ].filter { !$0.rows.isEmpty }
    }

    private static func buildApps(
        _ layer: KeyLayer,
        consumed: inout Set<UUID>
    ) -> [ShortcutRow] {
        layer.bindings
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
        _ layer: KeyLayer,
        consumed: Set<UUID>
    ) -> [ShortcutRow] {
        layer.bindings
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
    /// switch-layer, custom Lua) stay label-only by design. Panel-only:
    /// the shared catalog and the editor rows are untouched.
    private static func directionalIcon(for lua: String) -> String? {
        // A space or layer literally named a direction word would
        // otherwise false-match on the substring — those commands own
        // their own glyphs (space fallback / none), so bail first.
        guard !lua.contains("_space"),
            !lua.contains("switch_layer")
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
