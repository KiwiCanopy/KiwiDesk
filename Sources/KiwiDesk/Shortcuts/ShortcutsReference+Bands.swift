import Foundation
import KiwiDeskCore

/// Reference sheet band construction (#820).
extension ShortcutsReferenceBuilder {
    /// Builds standard control shortcut bands (`KeybindingCatalog`,
    /// `ShortcutsFamilyRows`, #678 Phase 3).
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
                desktops.desktops,
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

    /// Builds inactive shortcut rows (`OrphanedShortcuts`, #92, #820).
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
                if order == .orderedSame { return lhs.id < rhs.id }
                return order == .orderedAscending
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
                    monospaced: true
                )
            }
    }
}
