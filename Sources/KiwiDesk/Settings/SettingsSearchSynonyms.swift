/// Search index alternate vocabulary mapping (spec 11a). English
/// match-only, never displayed. Sparse by design: a synonym earns
/// its row by naming a REAL alternate vocabulary (another
/// platform's term, a retired noun), never by restating the label.
enum SettingsSearchSynonyms {
    /// Synonym terms for unmodeled catalog items (#1019,
    /// `SettingsSearchIndexTests`).
    static func catalogTerms(for id: String) -> [String] {
        if id == SettingsCatalog.macChecklist.guideLink.id {
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
        // The row's label moved from "Space" to "Opens in" in
        // #1022, so the two nouns a user arrives with — the one it
        // used to be called, and the relation's retired verb —
        // are the alternate vocabulary that has to reach it.
        case .appRules(.appRules):
            return ["space", "pin"]
        case .gaps(.outer): return ["margin", "padding"]
        case .gaps(.inner): return ["padding", "spacing"]
        case .borders(.borderEnabled):
            return ["outline", "focus ring", "highlight"]
        case .borders(.borderFocusedColor):
            return ["outline", "focus ring"]
        case .borders(.borderGlow):
            return ["neon", "shadow"]
        case .kiwishelf(.thickness):
            return ["height", "size"]
        case .kiwishelf(.minimum):
            return ["share", "split", "divider"]
        case .kiwishelf(.iconSource):
            return ["icon", "glyph"]
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
        case .colours(.animationsOnMonocleFocus):
            return ["card flip", "transition", "blur"]
        case .colours(.animationsMonocleFlipDurationMS):
            return ["speed", "flip speed"]
        case .colours(.paletteSave):
            return ["theme", "color scheme"]
        case .general(.language):
            return ["locale", "translation"]
        case .general(.appearance):
            return ["dark mode", "light mode", "theme"]
        case .general(.startAtLogin):
            return ["login item", "autostart", "launch"]
        case .general(.installUpdatesAutomatically):
            return ["auto update", "automatic updates", "sparkle"]
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
        // The label says "one window"; "single" is the other
        // word for it, and "alone" is the wire's (#1389).
        case .layout(.scrollingFillWhenAlone),
            .layout(.stackFillWhenAlone):
            return ["single window", "alone"]
        // The count stepper beneath this row is drawn under
        // Percent only, so it is not a hit of its own: its label
        // and the tiler nouns a user brings for it ride this row
        // (#1382).
        case .layout(.scrollingSlotSizeUnit):
            return ["columns", "rows", "windows on screen", "thirds"]
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
