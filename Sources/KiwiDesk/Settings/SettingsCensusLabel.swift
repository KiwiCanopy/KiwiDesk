import KiwiDeskCore

/// Renders a census key's row label at runtime — the label
/// authority the diff rows (#678 turn 9) and the search index
/// (spec 11a) read. The census stays key-only
/// (`SettingRowText`), and the English for those keys lives at
/// the live views' `L()` call sites — so a surface that renders
/// a label AWAY from its owning row cannot inline the English
/// without becoming a second authoring surface. Instead it
/// resolves through the shipped catalogs: the current locale
/// first (the manager's own lookup), then the `en.json`
/// manifest `scripts/extract-keys` regenerates from the call
/// sites. Loading that manifest at runtime is a deliberate
/// amendment to its build-time-only contract, recorded on
/// `LocaleCatalog` and argued in `docs/design-decisions.md` —
/// the alternative was 200+ English literals in a second switch
/// that drifts from the rows.
@MainActor
enum SettingsCensusLabel {
    /// The English manifest, loaded once. `en.json` is
    /// regenerated on every key change, so a stale value here
    /// can only be one build old — same staleness class as any
    /// bundled catalog.
    private static let english: [String: String] =
        LocaleCatalog.load("en")

    /// The localized label for a census-labelled key, or nil
    /// for `.dynamic` and unlabelled keys — those compose their
    /// text per instance at the surface that knows the
    /// instance (`SettingsValueReadout`).
    static func label(for key: SettingKey) -> String? {
        guard case .key(let labelKey) = key.text.label else {
            return nil
        }
        return string(labelKey)
    }

    /// Current-locale text for any catalog key, falling back to
    /// the English manifest, then to the key itself — a visible
    /// raw key beats a silent empty row, and
    /// `SettingKeyLocaleTests` keeps the fallback theoretical.
    static func string(_ key: String) -> String {
        L(key, english[key] ?? key)
    }
}
