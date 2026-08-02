import Foundation

/// Locale lookup for every user-facing string in the GUI
/// (issue #9). English is the source of truth, inlined at every
/// call site (`L("key", "English")`); a locale file only needs
/// to carry the keys it translates — any key it omits falls
/// back to the English argument, per-key.
///
/// Lives in `KiwiDeskCore` (not the GUI target) so both the
/// SwiftUI settings window and the AppKit quick menu
/// (`StatusItemController`) can call the same lookup.
@MainActor
public final class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()

    /// `nil` means "System default" — the macOS UI locale when a
    /// matching locale file ships, else English. A non-nil value
    /// is an explicit user pick (persisted by the GUI layer via
    /// `LocalizationPreference`, backed by `UserDefaults`; this
    /// manager does not read or write that store itself).
    @Published public private(set) var selection: String?
    /// The locale codes shipped as `Resources/Locales/*.json`,
    /// excluding `en`.
    public let available: [String]

    /// The effective locale's key -> translation dictionary.
    private var strings: [String: String] = [:]

    private init() {
        available = LocaleCatalog.availableLocales()
        reload()
    }

    /// The locale actually in effect right now: the explicit
    /// selection if shipped, else the macOS UI language if
    /// shipped, else English (`nil` meaning English — there is
    /// no `en.json` to load; English lives inline at call
    /// sites).
    ///
    /// "System default" reads `Locale.preferredLanguages` — the
    /// user's ordered language list — and not
    /// `Locale.current.language`, which is the *resolved* locale
    /// for this process and so answers whatever the bundle can
    /// serve. Inside the packaged `.app` that made the branch
    /// dead: `scripts/build-app.sh` declares
    /// `CFBundleLocalizations`, and until it did, macOS resolved
    /// every launch to `CFBundleDevelopmentRegion` (English) no
    /// matter the system language. Both halves are needed and
    /// neither is sufficient — a `swift run` build has no
    /// `Info.plist` at all, and the plist alone still leaves the
    /// script/region matching in `LocaleMatch` to do.
    public var effectiveLocale: String? {
        if let selection {
            // Explicit English: no `en.json` ships (English lives
            // inline), so it resolves to the empty dictionary —
            // inline English everywhere — never to the OS
            // language. Distinct from `nil` (System default).
            if selection == "en" { return nil }
            return available.contains(selection)
                ? selection : nil
        }
        return LocaleMatch.best(
            preferences: Locale.preferredLanguages,
            available: available
        )
    }

    /// Looks up `key` in the effective locale; returns `english`
    /// when the locale has no translation for it (per-key
    /// fallback) or when the effective locale is English.
    public func string(_ key: String, _ english: String) -> String {
        strings[key] ?? english
    }

    /// The interpolating counterpart of `string(_:_:)`: resolves
    /// the template (translation-or-English, same per-key
    /// fallback) then fills it with `args` via `String(format:)`.
    /// Templates use POSITIONAL specifiers (`%1$@`, `%2$d`, …),
    /// never bare `%@`/`%d` — positional lets a translation
    /// reorder an argument relative to the surrounding words,
    /// which is the entire reason this overload exists instead
    /// of `+`-concatenating a prefix and a value (issue #9
    /// review: a concatenated fragment can never be reordered by
    /// a translation, no matter how the target language's
    /// grammar wants it).
    public func string(
        _ key: String,
        _ english: String,
        _ args: [CVarArg]
    ) -> String {
        let template = strings[key] ?? english
        return String(format: template, arguments: args)
    }

    /// Updates the explicit selection and reloads the effective
    /// locale's strings. Pass `nil` to restore "System default".
    /// Persisting the choice (`LocalizationPreference`) is the
    /// caller's job (`SettingsModel+Language.swift`).
    public func select(_ locale: String?) {
        selection = locale
        reload()
    }

    /// Injects a persisted selection at startup, before any view
    /// reads `string(_:_:)`, without re-publishing twice — call
    /// this once, ahead of building the UI.
    public func adoptPersistedSelection(_ locale: String?) {
        selection = locale
        reload()
    }

    private func reload() {
        strings =
            effectiveLocale.map(LocaleCatalog.load) ?? [:]
    }
}

/// Shorthand call-site lookup: `L("menu.quit", "Quit KiwiDesk")`.
/// Delegates to `LocalizationManager.shared`. The single-letter
/// name is the deliberate convention (matches the terse `L(_:_:)`
/// idiom used by other gettext-style i18n APIs) — exempted from
/// swift-format's lower-camel-case rule below.
// swift-format-ignore: AlwaysUseLowerCamelCase
@MainActor
public func L(_ key: String, _ english: String) -> String {
    LocalizationManager.shared.string(key, english)
}

/// The interpolating overload: `L("monitor_chip.move_to",
/// "Move to %1$@", display.name)`. The template's positional
/// specifiers (`%1$@`, `%2$d`, …) let a translation reorder an
/// argument, unlike a `+`-concatenated prefix/suffix pair — use
/// this instead of building a sentence out of literal
/// concatenation whenever a value needs to sit inside English
/// prose. See `docs/translating.md` for the convention.
// swift-format-ignore: AlwaysUseLowerCamelCase
@MainActor
public func L(
    _ key: String,
    _ english: String,
    _ args: CVarArg...
) -> String {
    LocalizationManager.shared.string(key, english, args)
}
