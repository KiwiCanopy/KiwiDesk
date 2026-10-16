import AppKit
import KiwiDeskCore

/// A KiwiVision lens's shortcut row and the crossings a rename or
/// delete owes the stored bindings (#2103 rulings 11, 28, 39, 42).
extension KeybindingCatalog {
    /// The row that toggles `name`: the lens on turns KiwiVision
    /// off, any other turns that lens on (ruling 11).
    static func toggleLens(_ name: String) -> NavCommand {
        NavCommand(
            label: "Toggle \(name) lens",
            lua: "kiwivision.toggle(\(quote(name)))",
            displayLabel: {
                L("keybinding.toggle_lens", "Toggle %1$@ lens", name)
            },
            owns: { stored in
                lensTarget(of: stored).map {
                    AppWideSettings.sameLens($0, name)
                } ?? false
            }
        )
    }

    /// The lenses Settings draws a row for: every stored lens, plus
    /// every lens a binding names in any layer, so its chord stays
    /// visible and removable, as `desktopOffer` keeps a detached
    /// Desktop's. Each row owns every spelling of its lens
    /// (`NavCommand.owns`), so which spelling names it is moot.
    static func lensOffer(
        stored: [String],
        bindings: [KeyBinding]
    ) -> [String] {
        var offer = stored
        for name in bindings.compactMap({ lensTarget(of: $0.lua) })
        where !offer.contains(where: { AppWideSettings.sameLens($0, name) }) {
            offer.append(name)
        }
        return offer
    }

    /// The lens a toggle binding names, or nil for any other Lua —
    /// a bare `kiwivision.toggle()` included. Only the
    /// double-quoted form this catalog writes is read: a Lua user's
    /// `toggle('Writing')` is Custom Lua, outside the rows, the
    /// chips' chords and the crossings.
    static func lensTarget(of lua: String) -> String? {
        let prefix = "kiwivision.toggle("
        guard lua.hasPrefix(prefix), lua.hasSuffix(")") else {
            return nil
        }
        return LuaLiteral.parseString(
            String(lua.dropFirst(prefix.count).dropLast(1))
        )
    }

    /// Re-keys every binding that toggles `old` — ignoring case,
    /// as lens names compare (ruling 39) — to toggle `new`, its
    /// label following. A stale row for `new` in a layer that holds
    /// the renamed lens's own is dropped, so no lens gains a second
    /// chord (profiles.md ▸ one chord per navigation action).
    static func renameLens(
        in layers: [KeyLayer],
        from old: String,
        to new: String
    ) -> [KeyLayer] {
        let row = toggleLens(new)
        let respelled = AppWideSettings.sameLens(old, new)
        return layers.map { layer in
            var layer = layer
            // A stale row of the new name gives way to the renamed
            // lens's own chord.
            if !respelled,
                layer.bindings.contains(where: { names($0, old) })
            {
                layer.bindings.removeAll { names($0, new) }
            }
            layer.bindings = layer.bindings.map { binding in
                guard names(binding, old) else { return binding }
                var binding = binding
                binding.lua = row.lua
                binding.label = row.label
                return binding
            }
            return layer
        }
    }

    /// Drops every binding that toggles `name`: a deleted lens's
    /// chord is free again.
    static func deleteLens(
        in layers: [KeyLayer],
        named name: String
    ) -> [KeyLayer] {
        layers.map { layer in
            var layer = layer
            layer.bindings.removeAll { names($0, name) }
            return layer
        }
    }

    /// Whether `binding` toggles `lens`, by the one lens
    /// comparison (`AppWideSettings.sameLens`).
    static func names(_ binding: KeyBinding, _ lens: String) -> Bool {
        lensTarget(of: binding.lua).map {
            AppWideSettings.sameLens($0, lens)
        } ?? false
    }
}
