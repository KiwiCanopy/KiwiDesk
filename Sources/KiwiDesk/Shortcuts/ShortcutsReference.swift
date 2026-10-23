import Foundation
import KiwiDeskCore

/// Builds `ShortcutsReference` from a live key layer (`KeybindingCatalog`).
///
/// Suppresses the key panel's openers from rows (`ShortcutsSelfRowTests`,
/// #602, #2246). Unrecognized shortcuts fall through to the Custom band.
@MainActor
enum ShortcutsReferenceBuilder {
    static func build(
        layer: KeyLayer,
        spaces: [SpaceID],
        spaceIcons: [SpaceID: String],
        desktops: [Int],
        resizeStep: Int,
        layerNames: [String],
        lenses: [String] = [],
        unread: [UnreadChord] = []
    ) -> ShortcutsReference {
        // Drop the key panel's three openers from the working set
        // BEFORE any band builds, so the suppression holds by
        // construction: the panel's switch already prints each
        // side's chord (#2246). Scoped to callers entering HERE: the §2.1
        // split cost the band builders `private`, so a caller
        // invoking one directly would re-leak the seeded ⌃⌥K row
        // `ShortcutsSelfRowTests` pins — a band builder is
        // `build`'s to call.
        var layer = layer
        let openers = Set(JumpScope.allCases.map(\.lua))
        layer.bindings.removeAll { openers.contains($0.lua) }

        // Keyed by row identity (UUID), never `lua`: two bindings
        // can share a command's Lua with different combos (vim
        // keys + arrows). Keying by `lua` would consume the whole
        // command on the first match and drop the second from
        // every band — invisible, breaking "never drop a bound
        // shortcut". By id, the twin falls through to Custom.
        var consumed = Set<UUID>()

        func bound(_ lua: String) -> KeyBinding? {
            layer.bindings.first {
                $0.lua == lua && !$0.combo.isEmpty
            }
        }

        // Widened by the layer's own bindings, so a bound Desktop
        // row keeps its name instead of falling through to Custom
        // as raw Lua (the General band's #678 item 18 defect).
        // What the widening adds is exactly what is NOT attached,
        // so it is also the dim set.
        let offer = KeybindingCatalog.desktopOffer(
            live: desktops,
            bindings: layer.bindings
        )
        let places = ShortcutFold.places(
            spaces: spaces,
            desktops: offer.desktops,
            resizeStep: resizeStep
        )

        // A recognised binding that names another group leaves its
        // built-in band for it (#2544 ▸ Ruling): one of its own
        // here, a built-in one once the bands are built. An
        // inactive or unavailable row keeps its own section.
        var regrouped: [OwnRow] = []
        var moves: [String: ShortcutGroup] = [:]
        func rows(
            _ commands: [NavCommand],
            regroups: Bool
        ) -> [ShortcutRow] {
            commands.compactMap { cmd in
                guard let binding = bound(cmd.lua) else {
                    return nil
                }
                consumed.insert(binding.id)
                let combo = glyphs(binding.combo)
                // A field the binding sets wins; one it leaves empty
                // keeps the built-in name or symbol (#2544).
                var row = ShortcutRow(
                    id: cmd.lua,
                    label: binding.desc.isEmpty
                        ? cmd.resolvedLabel : binding.desc,
                    combo: combo,
                    icon: binding.meta.usableSymbol ?? icon(for: cmd),
                    unavailable: cmd.unavailable != nil,
                    fold: ShortcutFold.tag(
                        for: cmd,
                        at: places[cmd.lua],
                        combo: KeyCombo.parse(binding.combo),
                        rendered: combo
                    )
                )
                row.ownApp = cmd.lua == KeybindingCatalog.openSettings.lua
                guard regroups, cmd.unavailable == nil else { return row }
                switch ShortcutGroup.filing(binding.group) {
                case .none:
                    return row
                case .builtIn(let group):
                    moves[row.id] = group
                    return row
                case .own(let name):
                    regrouped.append(OwnRow(row: row, group: name))
                    return nil
                }
            }
        }

        let controls = buildControls(
            activeLayer: layer.name,
            spaces: spaces,
            spaceIcons: spaceIcons,
            desktops: offer,
            resizeStep: resizeStep,
            layerNames: layerNames,
            lenses: lenses,
            rows: { rows($0, regroups: true) }
        )
        // Inactive orphans built before Apps/Custom (#820).
        let inactive = buildInactive(
            layer,
            spaces: spaces,
            layers: layerNames,
            spaceIcons: spaceIcons,
            rows: { rows($0, regroups: false) }
        )
        // KiwiDesk's own app row leads Apps, as the editor's Open
        // applications ▸ KiwiDesk does (#1520, #2246); without it a
        // bound Open Settings fell through to Custom as raw Lua
        // (#678 item 18).
        let apps =
            rows([KeybindingCatalog.openSettings], regroups: true)
            + buildApps(layer, consumed: &consumed)
        let filed = file(
            regrouped + buildCustom(layer, consumed: consumed)
                + buildUnread(unread),
            controls: controls,
            apps: apps,
            moves: moves
        )

        // A key that does nothing until its Desktop returns leaves
        // its group, so the groups list only keys that work.
        let desktopAway = filed.controls.flatMap(\.rows)
            .filter(\.unavailable)
        let working = filed.controls.compactMap { group -> ShortcutSubgroup? in
            var group = group
            group.rows = group.rows.filter { !$0.unavailable }
            return group.rows.isEmpty ? nil : group
        }

        return ShortcutsReference(
            layerName: layer.name,
            controls: working,
            inactive: inactive,
            desktopAway: desktopAway,
            apps: filed.apps,
            groups: filed.groups,
            custom: filed.custom
        )
    }
}
