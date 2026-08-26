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
        desktops: KeybindingCatalog.DesktopOffer = .none,
        resizeStep: Int,
        layerNames: [String],
        rows: ([NavCommand]) -> [ShortcutRow]
    ) -> [ShortcutSubgroup] {
        let focus =
            KeybindingCatalog.focusDirections
            + KeybindingCatalog.goToSpace(spaces, icons: spaceIcons)
            + KeybindingCatalog.goToDesktop(
                desktops.focus,
                absent: desktops.absent
            )
        let move =
            KeybindingCatalog.swapDirections
            + KeybindingCatalog.moveToTrackRows
            + KeybindingCatalog.trackSwapRows
            + KeybindingCatalog.moveToSpace(
                spaces,
                icons: spaceIcons
            )
            + KeybindingCatalog.moveToDesktop(
                desktops.move,
                absent: desktops.absent
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
}
