import KiwiDeskCore

extension SettingKey {
    /// A label naming KiwiHub at `%1$@` through its one key
    /// (config-vocabulary.md ▸ KiwiHub, #2569), which the label
    /// resolver fills as it fills `labelMode`.
    var labelNamesKiwiHub: Bool { self == .kiwishelf(.tintHubAndPlates) }
}

/// Runtime localized label resolver for census setting keys
/// (`LocaleCatalog`, #678 turn 9).
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
        if key.labelNamesKiwiHub {
            return L(
                labelKey,
                english[labelKey] ?? labelKey,
                JumpScope.panelName
            )
        }
        guard let mode = key.labelMode else { return string(labelKey) }
        return L(
            labelKey,
            english[labelKey] ?? labelKey,
            mode.displayName
        )
    }

    /// Resolves localized string for key, falling back to English manifest
    /// (`SettingKeyLocaleTests`).
    static func string(_ key: String) -> String {
        L(key, english[key] ?? key)
    }
}
