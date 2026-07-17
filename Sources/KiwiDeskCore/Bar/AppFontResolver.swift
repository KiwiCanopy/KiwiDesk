import AppKit

/// The one place deciding "glyph or native image" for an app
/// shown in a bar (#294) — the icon-source gate lives HERE, so
/// consumers can't re-derive (and drift on) the policy. Three
/// consumers share it: the App Bar now, the Space Bar (#293)
/// and the shortcuts panel's Apps band. The bundled map loads
/// once off the main thread; until it arrives every lookup
/// answers nil and callers fall back to the native app image —
/// in practice invisible, the map is tiny and preloads at
/// startup.
///
/// The map is keyed on app **display names** (what upstream's
/// `appNames` lists, localized aliases included). Both current
/// consumers must feed the same name family: the bar passes
/// `window.appName`, the panel its row label — if those ever
/// diverge for an app, the surfaces show different symbols.
@MainActor
public final class AppFontResolver {
    /// Injectable for tests; defaults to the bundled map.
    private let loader: @Sendable () -> [String: String]?
    /// Fired once, after the map loads, so the owner can
    /// refresh bars that rendered image fallbacks meanwhile.
    /// Owner-only, single slot: `KiwiCore` sets it and fans
    /// out to every surface that needs a refresh (the Space
    /// Bar joins that fan-out in #293) — never reassign it
    /// from a consumer.
    public var onLoad: @MainActor () -> Void = {}

    private var map: [String: String]?
    private var loadStarted = false

    public init() {
        loader = { AppFontGlyphMap.loadBundled() }
    }

    /// Test seam: inject a map loader (spy or fixture).
    init(loader: @escaping @Sendable () -> [String: String]?) {
        self.loader = loader
    }

    /// Kicks the one-time background load; safe to call from
    /// every resolve (subsequent calls are a bool check).
    public func preload() {
        guard !loadStarted else { return }
        loadStarted = true
        let loader = self.loader
        Task.detached(priority: .utility) { [weak self] in
            // Warm the font registration (disk IO +
            // CTFontManager) off-main alongside the map, so
            // the first bar build never pays it on main.
            _ = AppFont.registered
            let loaded = loader()
            await MainActor.run {
                guard let self else { return }
                // Corrupt/missing map degrades to image-only
                // rendering (empty lookup), never a crash.
                self.map = loaded ?? [:]
                self.onLoad()
            }
        }
    }

    /// The ligature for an app's display name under `source`,
    /// or nil — when the source doesn't want glyphs, the map
    /// hasn't loaded yet, the app has no glyph, or the vendored
    /// font failed to register (no font, no glyphs). Callers
    /// fall back to the native app image on nil.
    public func glyph(
        forAppName name: String,
        source: BarAppIconSource
    ) -> String? {
        preload()
        guard source == .appFont, AppFont.registered else {
            return nil
        }
        // Empty ligatures are rejected HERE so no item view
        // ever needs its own blank-glyph guard (the map loader
        // also drops degenerate entries — that's hygiene, this
        // is the gate).
        return map?[name].flatMap {
            $0.isEmpty ? nil : $0
        }
    }
}
