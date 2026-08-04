import Foundation

/// One shipped locale's endonym (e.g. "Deutsch" for `de`) with
/// its first character capitalized *for that locale* — never
/// the English exonym. ONE owner for the General picker and the
/// Home card's language line, hoisted because the casing detail
/// is subtle and a second copy had already grown (review
/// 2026-08-04).
///
/// `localizedString(forIdentifier:)` returns the running-text
/// form, and Spanish, French, Italian and Russian do not
/// capitalize a language name mid-sentence — so the raw values
/// read "English, Deutsch, español, français…", capitalized only
/// where the language's own orthography happens to do it. In a
/// LIST that reads as a bug: macOS System Settings capitalizes
/// every entry, and matching it is the Apple-native call (§2.7).
/// Uppercasing with the entry's own locale keeps its casing
/// rules in charge; caseless scripts (日本語, 한국어, 中文) come
/// back untouched.
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
