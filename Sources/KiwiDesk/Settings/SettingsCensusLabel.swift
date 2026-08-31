import KiwiDeskCore

/// Runtime label resolver for census keys (#678 turn 9). A
/// surface rendering a label AWAY from its owning row cannot
/// inline the English without becoming a second authoring
/// surface, so it resolves through the shipped catalogs — the
/// current locale, then the `en.json` manifest. Loading that
/// manifest at runtime is a deliberate amendment to its
/// build-time-only contract, recorded on `LocaleCatalog` and
/// argued in `docs/design-decisions.md`.
@MainActor
enum SettingsCensusLabel {
    /// Bundled English translation manifest cache (`LocaleCatalog`).
    private static let english: [String: String] =
        LocaleCatalog.load("en")

    /// Localized label for census key, or nil for dynamic keys
    /// (`SettingsValueReadout`).
    static func label(for key: SettingKey) -> String? {
        guard case .key(let labelKey) = key.text.label else {
            return nil
        }
        return string(labelKey)
    }

    /// Resolves localized string for key, falling back to English manifest
    /// (`SettingKeyLocaleTests`).
    static func string(_ key: String) -> String {
        L(key, english[key] ?? key)
    }
}
