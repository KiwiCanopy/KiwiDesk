/// Search index alternate vocabulary mapping (spec 11a). English
/// match-only, never displayed. Sparse by design: a synonym earns
/// its row by naming a REAL alternate vocabulary (another
/// platform's term, a retired noun), never by restating the label.
enum SettingsSearchSynonyms {
    /// Synonym terms for unmodeled catalog items (#1019,
    /// `SettingsSearchIndexTests`).
    static func catalogTerms(for id: String) -> [String] {
        if id == SettingsCatalog.general.guideLink.id {
            return ["help", "docs", "documentation", "manual"]
        }
        // The two Desktop offers are the whole search surface
        // for their families (#1125), so the vocabulary a user
        // arrives with has to reach them: Apple names the
        // container "Mission Control", and the retired nouns are
        // what other tilers call a Desktop.
        if id
            == SettingsCatalog.shortcuts.focusDesktops.control
            .id
            || id
                == SettingsCatalog.shortcuts.moveWindowsDesktops
                .control.id
        {
            return [
                "mission control", "workspace", "virtual desktop",
            ]
        }
        return []
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
        case .colours(.liquidGlassMaster):
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
        // The checklist rows quote Apple's labels; these are the
        // words a user types before they know the label (#1365).
        case .macChecklist(.rearrangeSpaces):
            return ["mission control", "desktop order", "mru"]
        case .macChecklist(.stageManager):
            return ["stage manager"]
        case .macChecklist(.edgeTiling):
            return ["snap", "window tiling", "drag to edge"]
        case .macChecklist(.doubleClickTitle):
            return ["zoom", "double click", "title bar"]
        case .macChecklist(.habitHide):
            return ["hide", "minimize", "minimise", "yellow button"]
        case .macChecklist(.habitBigWindows):
            return [
                "maximize", "maximise", "green button",
                "full screen",
            ]
        case .macChecklist(.habitDock):
            return ["dock", "auto-hide dock"]
        default: return []
        }
    }
}
