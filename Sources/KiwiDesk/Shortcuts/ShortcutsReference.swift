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
        unread: [String] = []
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

        func rows(_ commands: [NavCommand]) -> [ShortcutRow] {
            commands.compactMap { cmd in
                guard let binding = bound(cmd.lua) else {
                    return nil
                }
                consumed.insert(binding.id)
                let icon =
                    cmd.icon.flatMap { $0.isEmpty ? nil : $0 }
                    ?? directionalIcon(for: cmd.lua)
                    ?? spaceFallbackIcon(for: cmd.lua)
                    ?? verbIcon(for: cmd.lua)
                let combo = glyphs(binding.combo)
                return ShortcutRow(
                    id: cmd.lua,
                    label: cmd.resolvedLabel,
                    combo: combo,
                    icon: icon,
                    unavailable: cmd.unavailable != nil,
                    fold: ShortcutFold.tag(
                        for: cmd,
                        at: places[cmd.lua],
                        combo: KeyCombo.parse(binding.combo),
                        rendered: combo
                    )
                )
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
            rows: rows
        )
        // Inactive orphans built before Apps/Custom (#820).
        let inactive = buildInactive(
            layer,
            spaces: spaces,
            layers: layerNames,
            spaceIcons: spaceIcons,
            rows: rows
        )
        // KiwiDesk's own app row leads Apps, as the editor's Open
        // applications ▸ KiwiDesk does (#1520, #2246); without it a
        // bound Open Settings fell through to Custom as raw Lua
        // (#678 item 18).
        let apps =
            rows([KeybindingCatalog.openSettings]).map { row in
                var row = row
                row.ownApp = true
                return row
            }
            + buildApps(layer, consumed: &consumed)
        let custom =
            buildCustom(layer, consumed: consumed)
            + buildUnread(unread)

        // A key that does nothing until its Desktop returns leaves
        // its group, so the groups list only keys that work.
        let desktopAway = controls.flatMap(\.rows).filter(\.unavailable)
        let working = controls.compactMap { group -> ShortcutSubgroup? in
            let rows = group.rows.filter { !$0.unavailable }
            return rows.isEmpty
                ? nil : ShortcutSubgroup(title: group.title, rows: rows)
        }

        return ShortcutsReference(
            layerName: layer.name,
            controls: working,
            inactive: inactive,
            desktopAway: desktopAway,
            apps: apps,
            custom: custom
        )
    }
}
