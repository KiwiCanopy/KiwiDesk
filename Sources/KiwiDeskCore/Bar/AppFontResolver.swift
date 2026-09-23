import AppKit

/// Resolves app icon glyph ligatures from vendored font map
/// (`BarAppIconSource`, #293, #294).
@MainActor
public final class AppFontResolver {
    /// Injectable for tests; defaults to bundled map.
    private let loader: @Sendable () -> AppFontGlyphMap?

    /// Callback fired once background map loading completes (`KiwiCore`).
    public var onLoad: @MainActor () -> Void = {}

    private var map: AppFontGlyphMap?
    private var loadStarted = false

    public init() {
        loader = { AppFontGlyphMap.loadBundled() }
    }

    /// Test seam: inject a map loader.
    init(loader: @escaping @Sendable () -> AppFontGlyphMap?) {
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
                self.map = loaded ?? AppFontGlyphMap([:])
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
        return map?.ligature(for: name)
    }
}
