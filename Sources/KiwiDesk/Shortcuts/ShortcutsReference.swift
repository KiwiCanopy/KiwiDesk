import Foundation
import KiwiDeskCore

/// Builds `ShortcutsReference` from a live key layer (`KeybindingCatalog`).
///
/// Suppresses `KiwiDesk.show_shortcuts()` from rows (`ShortcutsSelfRowTests`,
/// #602). Unrecognized shortcuts fall through to the Custom band.
@MainActor
enum ShortcutsReferenceBuilder {
    static func build(
        layer: KeyLayer,
        spaces: [SpaceID],
        spaceIcons: [SpaceID: String],
        desktops: [Int],
        resizeStep: Int,
        layerNames: [String]
    ) -> ShortcutsReference {
        // Drop the panel's own opener from the working set BEFORE
        // any band builds, so the suppression holds by
        // construction. Scoped to callers entering HERE: the §2.1
        // split cost the band builders `private`, so a caller
        // invoking one directly would re-leak the seeded ⌃⌥K row
        // `ShortcutsSelfRowTests` pins — a band builder is
        // `build`'s to call.
        var layer = layer
        layer.bindings.removeAll {
            $0.lua == ShortcutsOpenBinding.lua
        }

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
                return ShortcutRow(
                    id: cmd.lua,
                    label: cmd.resolvedLabel,
                    combo: glyphs(binding.combo),
                    icon: icon,
                    unavailable: cmd.unavailable != nil
                )
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
        let controls = buildControls(
            activeLayer: layer.name,
            spaces: spaces,
            spaceIcons: spaceIcons,
            desktops: offer,
            resizeStep: resizeStep,
            layerNames: layerNames,
            rows: rows
        )
        // Inactive orphans built before Apps/Custom (#820).
        let inactive = buildInactive(
            layer,
            spaces: spaces,
            spaceIcons: spaceIcons,
            rows: rows
        )
        let apps = buildApps(layer, consumed: &consumed)
        let custom = buildCustom(layer, consumed: consumed)

        return ShortcutsReference(
            layerName: layer.name,
            controls: controls,
            inactive: inactive,
            apps: apps,
            custom: custom
        )
    }
}
