import Foundation
import KiwiDeskCore

/// The reference builder's bands — one function per band, split
/// from `ShortcutsReference.swift` at the §2.1 file ceiling when
/// the Inactive band landed (#820). `build` still owns the order
/// they run in, and the `rows` closure they share (which consumes
/// a matched binding) lives there with it.
extension ShortcutsReferenceBuilder {
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
    static func buildControls(
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
            // The General band is the census's `generalKeys`
            // container, minus the panel's own opener — which
            // `build` already removed from the working set, so
            // this band holds whatever else that container
            // grows. Without it a bound Open Settings fell
            // through to Custom and rendered as raw
            // `KiwiDesk.open_settings()`, untranslated, in
            // every locale (#678 item 18).
            ShortcutSubgroup(
                title: L(
                    "shortcuts.section.general",
                    "General"
                ),
                rows: rows([KeybindingCatalog.openSettings])
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

    /// The Inactive band: bindings whose target Space has left
    /// the current list (#92's orphans), one surface over (#820).
    /// The predicate is Settings' own — `OrphanedShortcuts`, the
    /// pure half of `OrphanedShortcutsGroup` — so the panel and
    /// the editor cannot disagree about what is inactive, and
    /// the rows go through the same `rows` closure as every
    /// preset band, which is what gives them their real name
    /// ("Go to Space 6") and consumes them before Custom.
    ///
    /// Never pruned, and never invisible: the binding is orphaned
    /// only relative to the current Space set, still fires
    /// (recreating its Space) and still holds its combo — the
    /// argument is `OrphanedShortcutsGroup`'s docstring, and the
    /// panel's own "no bound shortcut is ever invisible" is the
    /// type docstring above.
    static func buildInactive(
        _ layer: KeyLayer,
        spaces: [SpaceID],
        spaceIcons: [SpaceID: String],
        rows: ([NavCommand]) -> [ShortcutRow]
    ) -> [ShortcutRow] {
        rows(
            OrphanedShortcuts.commands(
                bindings: layer.bindings,
                spaces: spaces,
                icons: spaceIcons
            )
        )
    }

    static func buildApps(
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

    static func buildCustom(
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
    static func directionalIcon(for lua: String) -> String? {
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
