import Foundation

/// Formats capitalized native endonym for a locale code (e.g. "Deutsch").
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
