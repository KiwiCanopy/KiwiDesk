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
        var layer = layer
        layer.bindings.removeAll {
            $0.lua == ShortcutsOpenBinding.lua
        }

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
