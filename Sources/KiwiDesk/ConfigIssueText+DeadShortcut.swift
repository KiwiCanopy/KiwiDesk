import KiwiDeskCore

/// A shortcut the install skipped (#2574): named by its chord, its
/// layer where that is not the default one, as the symbol issue is.
extension ConfigIssueText {
    @MainActor static func deadShortcut(
        layer: String,
        chord: String,
        reason: DeadShortcutReason
    ) -> String {
        let inDefault = layer == KeyLayer.defaultName
        switch reason {
        case .luaError(let message):
            // The interpreter's message stays English (#96).
            let keys = ShortcutsReferenceBuilder.glyphs(chord)
            guard inDefault else {
                return L(
                    "config_issues.dead_shortcut.lua_layer",
                    "The shortcut %1$@ in the “%3$@” layer does nothing: "
                        + "its Lua doesn't compile. %2$@",
                    keys,
                    message,
                    layer
                )
            }
            return L(
                "config_issues.dead_shortcut.lua",
                "The shortcut %1$@ does nothing: its Lua doesn't "
                    + "compile. %2$@",
                keys,
                message
            )
        case .invalidChord:
            // An unreadable chord has no glyphs; it is quoted as typed.
            guard inDefault else {
                return L(
                    "config_issues.dead_shortcut.chord_layer",
                    "The shortcut “%1$@” in the “%2$@” layer does "
                        + "nothing: its keys can't be read.",
                    chord,
                    layer
                )
            }
            return L(
                "config_issues.dead_shortcut.chord",
                "The shortcut “%1$@” does nothing: its keys can't be "
                    + "read.",
                chord
            )
        }
    }
}
