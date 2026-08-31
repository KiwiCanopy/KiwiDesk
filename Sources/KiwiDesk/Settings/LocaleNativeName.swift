import Foundation

/// Formats a locale's native endonym (never the English exonym),
/// capitalized FOR THAT LOCALE: `localizedString(forIdentifier:)`
/// returns running-text casing ("español"), which reads as a bug
/// in a list; uppercasing with the entry's own locale keeps its
/// rules in charge and leaves caseless scripts untouched.
enum LocaleNativeName {
    static func name(for code: String) -> String {
        let locale = Locale(identifier: code)
        let raw =
            locale.localizedString(forIdentifier: code) ?? code
        guard let first = raw.first else { return raw }
        return String(first).uppercased(with: locale)
            + raw.dropFirst()
    }
}
