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
            }
        )
    }

    /// The lens a toggle binding names, or nil for any other Lua —
    /// a bare `kiwivision.toggle()` included.
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
    /// label following. A layer already holding a row for `new`
    /// keeps that one and drops the old, so no lens gains a second
    /// chord (profiles.md ▸ one chord per navigation action).
    static func renameLens(
        in layers: [KeyLayer],
        from old: String,
        to new: String
    ) -> [KeyLayer] {
        let row = toggleLens(new)
        let respelled = old.caseInsensitiveCompare(new) == .orderedSame
        return layers.map { layer in
            if !respelled,
                layer.bindings.contains(where: { names($0, new) })
            {
                return deleteLens(in: [layer], named: old)[0]
            }
            var layer = layer
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

    private static func names(_ binding: KeyBinding, _ lens: String) -> Bool {
        lensTarget(of: binding.lua).map {
            $0.caseInsensitiveCompare(lens) == .orderedSame
        } ?? false
    }
}
