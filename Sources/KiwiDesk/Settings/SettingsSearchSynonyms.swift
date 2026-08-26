/// Match-only alternate vocabulary for the search index (spec
/// 11a): the words a user types when they do not know KiwiDesk's
/// noun yet. English only and never displayed — the localized
/// LABEL is what the user sees and what locale-language queries
/// match, so a synonym here widens matching without becoming a
/// translated string, and it stays code data rather than a
/// catalog key.
///
/// Keyed on the census case itself, so an entry for a renamed or
/// deleted setting is a compile error, never dead data. Sparse
/// by design: a synonym earns its row by naming a REAL alternate
/// vocabulary (another platform's term, a retired noun, a common
/// near-miss) — not by restating the label, which already
/// matches.
enum SettingsSearchSynonyms {
    /// The same widening for a CATALOG-only row — one the census
    /// does not model as a setting, so it has no `SettingKey` to
    /// key on (#1019).
    ///
    /// Keyed on the declaration's own `id` rather than on a
    /// string literal, so renaming the catalog property is a
    /// compile error and re-keying it follows automatically —
    /// as close to the census switch's compile-time safety as a
    /// keyless row can get. `SettingsSearchIndexTests` holds the
    /// rest: an entry naming a control the catalog does not
    /// declare is dead vocabulary nothing can match.
    ///
    /// **English only, like the census half, and that is a real
    /// limit rather than an oversight.** A synonym is match-only
    /// code data, never a displayed or translated string — so a
    /// German reader finds this row by its LABEL ("Handbuch"),
    /// which is the word on screen, and typing "Hilfe" matches
    /// nothing. Localized synonyms would be a different
    /// mechanism and its own decision.
    static func catalogTerms(for id: String) -> [String] {
        // Every Mac app has a Help menu and this app, being
        // `.accessory`, has none — so "help" is the word a stuck
        // reader types, and the guide is what they are reaching
        // for. "docs" is the site's other tree by name.
        guard id == SettingsCatalog.general.guideLink.id else {
            return []
        }
        return ["help", "docs", "documentation", "manual"]
    }

    static func terms(for key: SettingKey) -> [String] {
        switch key {
        // Gaps: CSS/System-Settings vocabulary.
        case .gaps(.outer): return ["margin", "padding"]
        case .gaps(.inner): return ["padding", "spacing"]
        // Borders: the noun glossary retired "outline"/"ring"
        // in copy; users still type them.
        case .borders(.borderEnabled):
            return ["outline", "focus ring", "highlight"]
        case .borders(.borderFocusedColor):
            return ["outline", "focus ring"]
        case .borders(.borderGlow):
            return ["neon", "shadow"]
        // Bars: a bar has a thickness, users ask for height.
        case .appBar(.appBarThickness),
            .spaceBar(.spaceBarThickness):
            return ["height", "size"]
        case .appBar(.appBarLiquidGlass),
            .spaceBar(.spaceBarLiquidGlass):
            return ["glass", "translucent", "transparency"]
        // Motion: speed is the word, duration is the setting.
        case .colours(.animationsMaster):
            return ["motion", "movement"]
        case .colours(.animationsDurationMS):
            return ["speed", "animation speed"]
        // Palettes read as themes elsewhere. Only the save row
        // carries the synonyms: the shelf's apply tile is a
        // `.dynamic`-labelled instance row the index excludes.
        case .colours(.paletteSave):
            return ["theme", "color scheme"]
        // General: the OS's own vocabulary.
        case .general(.language):
            return ["locale", "translation"]
        case .general(.appearance):
            return ["dark mode", "light mode", "theme"]
        case .general(.startAtLogin):
            return ["login item", "autostart", "launch"]
        // Behaviour near-misses.
        case .behaviour(.mouseFollowsFocus):
            return ["focus follows mouse", "hover focus"]
        case .behaviour(.minWindowSize):
            return ["minimum size"]
        default: return []
        }
    }
}
