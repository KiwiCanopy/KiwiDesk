/// Search index alternate vocabulary mapping (spec 11a). English
/// match-only, never displayed. Sparse by design: a synonym earns
/// its row by naming a REAL alternate vocabulary (another
/// platform's term, a retired noun), never by restating the label.
enum SettingsSearchSynonyms {
    /// Synonym terms for unmodeled catalog items (#1019,
    /// `SettingsSearchIndexTests`).
    static func catalogTerms(for id: String) -> [String] {
        guard id == SettingsCatalog.general.guideLink.id else {
            return []
        }
        return ["help", "docs", "documentation", "manual"]
    }

    /// Alternate vocabulary terms for census setting keys.
    static func terms(for key: SettingKey) -> [String] {
        switch key {
        case .gaps(.outer): return ["margin", "padding"]
        case .gaps(.inner): return ["padding", "spacing"]
        case .borders(.borderEnabled):
            return ["outline", "focus ring", "highlight"]
        case .borders(.borderFocusedColor):
            return ["outline", "focus ring"]
        case .borders(.borderGlow):
            return ["neon", "shadow"]
        case .appBar(.appBarThickness),
            .spaceBar(.spaceBarThickness):
            return ["height", "size"]
        case .appBar(.appBarLiquidGlass),
            .spaceBar(.spaceBarLiquidGlass):
            return ["glass", "translucent", "transparency"]
        case .colours(.animationsMaster):
            return ["motion", "movement"]
        // Speed is the word people reach for; duration is what
        // the setting stores (#1020).
        case .colours(.animationsDurationMS):
            return ["speed", "animation speed"]
        case .colours(.animationsScrollDurationMS):
            return ["speed", "scroll speed", "scrolling speed"]
        case .colours(.paletteSave):
            return ["theme", "color scheme"]
        case .general(.language):
            return ["locale", "translation"]
        case .general(.appearance):
            return ["dark mode", "light mode", "theme"]
        case .general(.startAtLogin):
            return ["login item", "autostart", "launch"]
        case .shortcuts(.toggleSticky),
            .shortcuts(.toggleDisplaySticky):
            // The SHORTCUTS carry "pin", not the appearance rows
            // (owner 2026-08-26): someone typing it wants to pin
            // a window, not style the mark that says one is
            // pinned.
            return [
                "pin", "pinned", "always on top", "all desktops",
            ]
        case .shortcuts(.restoreDefaults):
            return [
                "reset", "reset shortcuts", "factory",
                "original shortcuts", "stock shortcuts",
            ]
        case .behaviour(.mouseFollowsFocus):
            return ["focus follows mouse", "hover focus"]
        case .behaviour(.minWindowSize):
            return ["minimum size"]
        default: return []
        }
    }
}
