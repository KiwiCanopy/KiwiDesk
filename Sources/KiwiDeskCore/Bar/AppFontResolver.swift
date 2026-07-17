import AppKit

/// The one place deciding "glyph or native image" for an app
/// shown in a bar (#294). Three consumers share it: the App
/// Bar now, the Space Bar (#293) and the shortcuts panel's
/// Apps band. The bundled map loads once off the main thread;
/// until it arrives every lookup answers nil and callers fall
/// back to the native app image — in practice invisible, the
/// map is tiny and preloads at startup.
@MainActor
public final class AppFontResolver {
    /// Injectable for tests; defaults to the bundled map.
    private let loader: @Sendable () -> [String: String]?
    /// Fired once, after the map loads, so the owner can
    /// refresh bars that rendered image fallbacks meanwhile.
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
        Task.detached(priority: .utility) {
            let loaded = loader()
            await MainActor.run { [weak self] in
                guard let self else { return }
                // Corrupt/missing map degrades to image-only
                // rendering (empty lookup), never a crash.
                self.map = loaded ?? [:]
                self.onLoad()
            }
        }
    }

    /// The ligature for an app's display name, or nil when the
    /// map hasn't loaded yet, the app has no glyph, or the
    /// vendored font failed to register (no font, no glyphs) —
    /// callers fall back to the native app image.
    public func glyph(forAppName name: String) -> String? {
        preload()
        guard AppFont.registered else { return nil }
        return map?[name]
    }
}
