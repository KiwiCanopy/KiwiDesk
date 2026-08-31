import AppKit

/// Resolves app icon glyph ligatures from the vendored font map
/// (`BarAppIconSource`, #293, #294). Keyed on app DISPLAY names:
/// every consumer must feed the same name family (the bar passes
/// `window.appName`, the panel its row label) — diverge and the
/// surfaces show different symbols.
@MainActor
public final class AppFontResolver {
    /// Injectable for tests; defaults to bundled map.
    private let loader: @Sendable () -> [String: String]?

    /// Callback fired once map loading completes. Owner-only,
    /// single slot: `KiwiCore` sets it and fans out to every
    /// surface needing a refresh — never reassign from a
    /// consumer.
    public var onLoad: @MainActor () -> Void = {}

    private var map: [String: String]?
    private var loadStarted = false

    public init() {
        loader = { AppFontGlyphMap.loadBundled() }
    }

    /// Test seam: inject a map loader.
    init(loader: @escaping @Sendable () -> [String: String]?) {
        self.loader = loader
    }

    /// Kicks off asynchronous map preloading.
    public func preload() {
        guard !loadStarted else { return }
        loadStarted = true
        let loader = self.loader
        Task.detached(priority: .utility) { [weak self] in
            _ = AppFont.registered
            let loaded = loader()
            await MainActor.run {
                guard let self else { return }
                self.map = loaded ?? [:]
                self.onLoad()
            }
        }
    }

    /// Returns app font ligature for app name under given icon source
    /// (`AppFont.registered`).
    public func glyph(
        forAppName name: String,
        source: BarAppIconSource
    ) -> String? {
        preload()
        guard source == .appFont, AppFont.registered else {
            return nil
        }
        // Empty ligatures are rejected HERE so no item view ever
        // needs its own blank-glyph guard — this is the gate, the
        // loader's dropping of degenerate entries is only hygiene.
        return map?[name].flatMap {
            $0.isEmpty ? nil : $0
        }
    }
}
