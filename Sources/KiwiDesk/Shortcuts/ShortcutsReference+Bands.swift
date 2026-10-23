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
        lenses: [String] = [],
        rows: ([NavCommand], ShortcutGroup?) -> [ShortcutRow]
    ) -> [ShortcutSubgroup] {
        let focus =
            KeybindingCatalog.focusDirections
            + [KeybindingCatalog.screenLastRow]
            + KeybindingCatalog.spaceStepRows
            + KeybindingCatalog.spaceHistoryRows
            + KeybindingCatalog.goToSpace(spaces, icons: spaceIcons)
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
        // A band names its group once: its rows are filed against it.
        func band(
            _ title: String,
            _ group: ShortcutGroup?,
            _ commands: [NavCommand]
        ) -> ShortcutSubgroup {
            ShortcutSubgroup(
                title: title,
                rows: rows(commands, group),
                group: group
            )
        }
        return [
            band(ShortcutGroup.focus.title, .focus, focus),
            band(
                ShortcutGroup.moveWindows.title,
                .moveWindows,
                move
            ),
            band(
                ShortcutGroup.layout.title,
                .layout,
                KeybindingCatalog.layoutRows
            ),
            band(
                ShortcutGroup.sizeFloat.title,
                .sizeFloat,
                KeybindingCatalog.resizeAndFloat(step: resizeStep)
            ),
            // A section of its own, empty and so dropped while no
            // KiwiVision key is bound (#2312).
            band(
                ShortcutGroup.kiwivision.title,
                .kiwivision,
                [KeybindingCatalog.toggleKiwiVision]
                    + lenses.map(KeybindingCatalog.toggleLens)
            ),
            // The bars' show/hide shortcuts (#761).
            band(
                ShortcutGroup.kiwishelf.title,
                .kiwishelf,
                [
                    KeybindingCatalog.toggleSpaceBar,
                    KeybindingCatalog.toggleAppBar,
                ]
            ),
            band(
                L("shortcuts.section.switch_layers", "Switch layers"),
                nil,
                switchLayers
            ),
        ]
        // Empty bands stay: a binding may still file into one, and
        // the reference drops what is left empty (#2544).
        .map {
            var group = $0
            group.rows = ShortcutFold.folded($0.rows)
            return group
        }
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

    /// A binding of the user's own and the group it files into
    /// (#2544): its description in place of its Lua, its symbol
    /// where that is an SF Symbol, else the Lua mark.
    struct OwnRow {
        let row: ShortcutRow
        let group: String
    }

    /// Builds custom shortcut rows for remaining unconsumed bindings.
    static func buildCustom(
        _ layer: KeyLayer,
        consumed: Set<UUID>
    ) -> [OwnRow] {
        layer.bindings
            .filter {
                !$0.combo.isEmpty && !consumed.contains($0.id)
            }
            .map { binding in
                OwnRow(
                    row: ShortcutRow(
                        id: binding.id.uuidString,
                        label: binding.desc.isEmpty
                            ? binding.lua : binding.desc,
                        combo: glyphs(binding.combo),
                        icon: ownIcon(binding.meta),
                        monospaced: binding.desc.isEmpty
                    ),
                    group: binding.group
                )
            }
    }

    /// Rows for Lua-owned chords whose action `init.lua` does not
    /// spell inline (a named handler, a C function): the chord is
    /// registered, so it is listed, under its description or a
    /// generic name (#2482, #2544).
    static func buildUnread(_ chords: [UnreadChord]) -> [OwnRow] {
        chords.map { unread in
            OwnRow(
                row: ShortcutRow(
                    id: "unread:" + unread.chord,
                    label: unread.meta.desc.isEmpty
                        ? L("shortcuts.panel.lua_function", "Lua function")
                        : unread.meta.desc,
                    combo: glyphs(unread.chord),
                    icon: ownIcon(unread.meta)
                ),
                group: unread.meta.group
            )
        }
    }

    /// A binding's own symbol where it names an SF Symbol, else the
    /// Lua mark; a name that is none is a Config Issue (#2544).
    static func ownIcon(_ meta: KeyBindingMeta) -> String {
        meta.usableSymbol ?? LuaMark.symbol
    }
}
