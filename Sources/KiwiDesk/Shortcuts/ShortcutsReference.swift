import Foundation
import KiwiDeskCore

/// Builds a `ShortcutsReference` from a live key layer by filtering
/// the `KeybindingCatalog` presets to the bindings that actually
/// exist — reusing the exact labels, icons, and Lua identity the
/// editor authors, so the panel can never disagree with the tab.
/// Anything bound but unrecognized (custom Lua, or a resize of a
/// non-current step) falls through to the Custom band, so no bound
/// shortcut is ever invisible — with one deliberate exception:
/// `KiwiDesk.show_shortcuts()` opens this very panel, so it is
/// dropped from the working set before any band builds and never
/// becomes a row in any of them. The footer's dismiss hint
/// teaches its combo in every state whose bindings are live
/// (paused bindings do nothing, so the generic hint is honest
/// there). Un-suppressing it would re-leak the seeded ⌃⌥K
/// default (#602) into Custom as raw Lua — the band that means
/// "user-authored". `ShortcutsSelfRowTests` pins the exception.
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
        // The panel's own opener never renders as a row (see the
        // type docstring): drop every binding of it — whatever its
        // kind or combo — from the working set before any band
        // builds, so the suppression holds across every band by
        // construction, not by each band's filter remembering.
        //
        // "By construction" is now scoped to callers entering
        // HERE: the §2.1 split put the band builders in
        // `+Bands.swift`, which cost them `private`, so a
        // module-level caller invoking one directly would hand it
        // an unfiltered layer and re-leak the seeded ⌃⌥K row
        // `ShortcutsSelfRowTests` pins. Nothing scans for that —
        // a band builder is `build`'s to call.
        var layer = layer
        layer.bindings.removeAll {
            $0.lua == ShortcutsOpenBinding.lua
        }

        // Keyed by row identity (UUID), not `lua`: two bindings can
        // share a command's Lua with different combos (vim keys +
        // arrows both bound to `focus("left")`). Keying by `lua`
        // would consume the whole command on the first match and
        // drop the second from every band — invisible, breaking the
        // "never drop a bound shortcut" contract. By id, only the
        // matched row is consumed; the twin falls through to Custom.
        var consumed = Set<UUID>()

        // A bound binding (non-empty combo) for a preset's Lua.
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
                // Custom space icon first, then a directional arrow
                // for compass commands, then a space fallback so a
                // space row always carries a glyph even when the user
                // set no icon for it.
                let icon =
                    cmd.icon.flatMap { $0.isEmpty ? nil : $0 }
                    ?? directionalIcon(for: cmd.lua)
                    ?? spaceFallbackIcon(for: cmd.lua)
                return ShortcutRow(
                    id: cmd.lua,
                    label: cmd.resolvedLabel,
                    combo: glyphs(binding.combo),
                    icon: icon
                )
            }
        }

        let controls = buildControls(
            activeLayer: layer.name,
            spaces: spaces,
            spaceIcons: spaceIcons,
            // Widened by the layer's own bindings, so a bound
            // Desktop row keeps its name here instead of
            // falling through to Custom as raw Lua — the band
            // that means "user-authored" (the General band's
            // #678 item 18 note is the same defect).
            desktops: KeybindingCatalog.offeredDesktops(
                live: desktops,
                bindings: layer.bindings
            ),
            resizeStep: resizeStep,
            layerNames: layerNames,
            rows: rows
        )
        // Before Apps and Custom, so an orphan is consumed as
        // what it is rather than falling through to the band
        // that means "user-authored" (#820).
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
