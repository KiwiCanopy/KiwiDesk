import Foundation

/// Locale lookup for user-facing GUI strings with inline English fallback
/// (#9).
@MainActor
public final class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()

    /// Explicit user selection (`nil` for system default).
    @Published public private(set) var selection: String?
    /// Available locale codes from bundled `Resources/Locales/*.json`.
    public let available: [String]

    private var strings: [String: String] = [:]

    private init() {
        available = LocaleCatalog.availableLocales()
        reload()
    }

    /// Effective locale code (`nil` for inline English fallback, #659).
    public var effectiveLocale: String? {
        if let selection {
            if selection == "en" { return nil }
            return available.contains(selection)
                ? selection : nil
        }
        return LocaleMatch.best(
            preferences: Locale.preferredLanguages,
            available: available
        )
    }

    /// Looks up translation for `key`, falling back to `english`.
    public func string(_ key: String, _ english: String) -> String {
        strings[key] ?? english
    }

    /// Looks up format template and interpolates positional `args` (#9).
    public func string(
        _ key: String,
        _ english: String,
        _ args: [CVarArg]
    ) -> String {
        let template = strings[key] ?? english
        return String(format: template, arguments: args)
    }

    /// Updates explicit locale selection and reloads translations.
    public func select(_ locale: String?) {
        selection = locale
        reload()
    }

    /// Seeds persisted locale selection at startup.
    public func adoptPersistedSelection(_ locale: String?) {
        selection = locale
        reload()
    }

    private func reload() {
        strings =
            effectiveLocale.map(LocaleCatalog.load) ?? [:]
    }
}

/// Shorthand string lookup with inline English fallback (#9).
// swift-format-ignore: AlwaysUseLowerCamelCase
@MainActor
public func L(_ key: String, _ english: String) -> String {
    LocalizationManager.shared.string(key, english)
}

/// Shorthand string lookup with positional argument interpolation (#9).
// swift-format-ignore: AlwaysUseLowerCamelCase
@MainActor
public func L(
    _ key: String,
    _ english: String,
    _ args: CVarArg...
) -> String {
    LocalizationManager.shared.string(key, english, args)
}
