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
