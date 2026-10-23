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
        rows: ([NavCommand]) -> [ShortcutRow]
    ) -> [ShortcutSubgroup] {
        let focus =
            KeybindingCatalog.focusDirections
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
        return [
            ShortcutSubgroup(
                title: L("shortcuts.section.focus", "Focus"),
                rows: rows(focus),
                group: .focus
            ),
            ShortcutSubgroup(
                title: L(
                    "shortcuts.section.move_windows",
                    "Move windows"
                ),
                rows: rows(move),
                group: .moveWindows
            ),
            ShortcutSubgroup(
                title: L("shortcuts.section.layout", "Layout"),
                rows: rows(KeybindingCatalog.layoutRows),
                group: .layout
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
                ),
                group: .sizeFloat
            ),
            // A section of its own, empty and so dropped while no
            // KiwiVision key is bound (#2312).
            ShortcutSubgroup(
                title: L("destination.kiwivision", "KiwiVision"),
                rows: rows(
                    [KeybindingCatalog.toggleKiwiVision]
                        + lenses.map(KeybindingCatalog.toggleLens)
                ),
                group: .kiwivision
            ),
            // The bars' show/hide shortcuts (#761).
            ShortcutSubgroup(
                title: L("bars.switch.kiwishelf", "KiwiShelf"),
                rows: rows(
                    [
                        KeybindingCatalog.toggleSpaceBar,
                        KeybindingCatalog.toggleAppBar,
                    ]
                ),
                group: .kiwishelf
            ),
            ShortcutSubgroup(
                title: L(
                    "shortcuts.section.switch_layers",
                    "Switch layers"
                ),
                rows: rows(switchLayers)
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

    /// The Lua mark: what a binding of your own wears without a
    /// symbol of its own, everywhere KiwiDesk marks Lua (#2544).
    static let luaMark = "chevron.left.forwardslash.chevron.right"

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
                        icon: ownIcon(binding.symbol),
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
    static func buildUnread(
        _ chords: [String],
        meta: (String) -> KeyBindingMeta = { _ in .none }
    ) -> [OwnRow] {
        chords.map { chord in
            let meta = meta(chord)
            return OwnRow(
                row: ShortcutRow(
                    id: "unread:" + chord,
                    label: meta.desc.isEmpty
                        ? L("shortcuts.panel.lua_function", "Lua function")
                        : meta.desc,
                    combo: glyphs(chord),
                    icon: ownIcon(meta.symbol)
                ),
                group: meta.group
            )
        }
    }

    /// A binding's own symbol where it names an SF Symbol, else the
    /// Lua mark; a name that is none is a Config Issue (#2544).
    static func ownIcon(_ symbol: String) -> String {
        symbol.isEmpty || !KiwiCore.iconIsSymbol(symbol) ? luaMark : symbol
    }
}
