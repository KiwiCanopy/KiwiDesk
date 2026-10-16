import Foundation
import KiwiDeskCore

/// Reference sheet band construction (#820).
extension ShortcutsReferenceBuilder {
    /// Builds standard control shortcut bands. Membership twin of
    /// the editor's grouping: row identity is single-sourced from
    /// `KeybindingCatalog`, only the GROUPING is mirrored, and a
    /// forgotten command degrades to Custom, never vanishes. A
    /// family added to the census owes this builder a band too,
    /// until it consumes the expander (`ShortcutsFamilyRows`,
    /// #678 Phase 3) — the real fix, but a panel behaviour change
    /// of its own.
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
            + KeybindingCatalog.spaceStepRows
            + KeybindingCatalog.spaceHistoryRows
            + KeybindingCatalog.goToSpace(spaces, icons: spaceIcons)
            + [KeybindingCatalog.toggleKiwiVision]
            + KeybindingCatalog.goToDesktop(
                desktops.desktops,
                absent: desktops.absent
            )
        let move =
            KeybindingCatalog.swapDirections
            + KeybindingCatalog.trackRows
            + KeybindingCatalog.moveToSpace(
                spaces,
                icons: spaceIcons
            )
            + KeybindingCatalog.moveToDesktop(
                desktops.desktops,
                absent: desktops.absent
            )
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
                title: L("shortcuts.section.layout", "Layout"),
                rows: rows(KeybindingCatalog.layoutRows)
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
        ]
        .map {
            ShortcutSubgroup(
                title: $0.title,
                rows: ShortcutFold.folded($0.rows)
            )
        }
        .filter { !$0.rows.isEmpty }
    }

    /// Builds inactive shortcut rows (`OrphanedShortcuts`, #92, #820).
    static func buildInactive(
        _ layer: KeyLayer,
        spaces: [SpaceID],
        layers: [String],
        spaceIcons: [SpaceID: String],
        rows: ([NavCommand]) -> [ShortcutRow]
    ) -> [ShortcutRow] {
        rows(
            OrphanedShortcuts.commands(
                bindings: layer.bindings,
                spaces: spaces,
                layers: layers,
                icons: spaceIcons
            )
        )
    }

    /// Builds application launch shortcut rows (#334, `recomputeOrder`).
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
                let action = KeybindingCatalog.appShortcutAction(
                    from: binding.lua
                )
                let badge = Self.actionBadge(action)
                return ShortcutRow(
                    id: binding.id.uuidString,
                    label: name,
                    combo: glyphs(binding.combo),
                    bundleID: bundleID,
                    accessoryIcon: badge?.icon,
                    accessoryHelp: badge?.help ?? ""
                )
            }
            .sorted { lhs, rhs in
                let order = lhs.label
                    .localizedCaseInsensitiveCompare(rhs.label)
                if order == .orderedSame { return lhs.id < rhs.id }
                return order == .orderedAscending
            }
    }

    /// The row badge for a action other than Open or Focus: its
    /// symbol and the help naming what the key does.
    static func actionBadge(
        _ action: AppShortcutAction?
    ) -> (icon: String, help: String)? {
        switch action {
        case .openNew:
            return (
                "macwindow.badge.plus",
                L(
                    "shortcuts.app_behavior.open_new.badge",
                    "Opens a new instance"
                )
            )
        // Not the floating mark's symbol, which the Shortcuts side
        // shows beside it for a different meaning (#2246).
        case .gather:
            return (
                "rectangle.stack",
                L(
                    "shortcuts.app_behavior.gather.badge",
                    "Gathers its windows here"
                )
            )
        case .openOrFocus, nil:
            return nil
        }
    }

    /// Builds custom shortcut rows for remaining unconsumed bindings.
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
                    icon: "curlybraces",
                    monospaced: true
                )
            }
    }
}
