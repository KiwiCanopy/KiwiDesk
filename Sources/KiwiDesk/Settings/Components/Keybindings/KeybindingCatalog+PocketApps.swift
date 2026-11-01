import KiwiDeskCore

/// An app's Pocket key row (#2612 ▸ 6): a navigation binding whose
/// Lua is exactly `PocketAppLuaArg.call`, read back by
/// `PocketAppLuaArg.bundleID(of:)` alone, as Core reads it.
extension KeybindingCatalog {
    /// The row for `bundleID`: "Pocket ‹app›", so its name tells it
    /// from the app's Open key wherever a binding is named.
    static func pocketApp(_ bundleID: String) -> NavCommand {
        let name = displayName(forBundleID: bundleID)
        return NavCommand(
            label: "Pocket \(name)",
            lua: PocketAppLuaArg.call(bundleID),
            // "Pocket" is the verb: the app's pocket window goes
            // away or comes out.
            displayLabel: {
                L("shortcuts.pocket_app.row", "Pocket %1$@", name)
            }
        )
    }

    /// The apps `bindings` give a Pocket key, in binding order.
    static func pocketApps(in bindings: [KeyBinding]) -> [String] {
        var seen = Set<String>()
        return bindings.compactMap {
            PocketAppLuaArg.bundleID(of: $0.lua)
        }
        .filter { seen.insert($0).inserted }
    }

    /// A new row for `bundleID`, kind `navigation`, with no chord.
    static func pocketAppBinding(
        _ bundleID: String
    ) -> KeyBinding {
        let command = pocketApp(bundleID)
        var binding = KeyBinding(kind: .navigation)
        binding.label = command.label
        binding.lua = command.lua
        return binding
    }
}
