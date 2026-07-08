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
    /// is an explicit user pick (persisted by the GUI layer into
    /// `gui.json`; this manager does not read or write that
    /// file itself).
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
    public var effectiveLocale: String? {
        if let selection {
            return available.contains(selection)
                ? selection : nil
        }
        let system = String(
            Locale.current.language.languageCode?
                .identifier ?? ""
        )
        return available.contains(system) ? system : nil
    }

    /// Looks up `key` in the effective locale; returns `english`
    /// when the locale has no translation for it (per-key
    /// fallback) or when the effective locale is English.
    public func string(_ key: String, _ english: String) -> String {
        strings[key] ?? english
    }

    /// Updates the explicit selection and reloads the effective
    /// locale's strings. Pass `nil` to restore "System default".
    /// Persisting the choice into `gui.json` is the caller's
    /// job (`GeneralSection` / the GUI's config-apply seam).
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
