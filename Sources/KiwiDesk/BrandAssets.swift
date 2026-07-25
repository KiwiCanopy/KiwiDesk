import AppKit
import KiwiDeskCore

/// Bundled brand images (#68 §3.8/§3.9), rasterized from the
/// vector masters in `assets/` (see `assets/README.md` for
/// the regeneration commands). Every accessor is optional — a
/// missing resource falls back to the SF Symbol placeholder
/// at the call site, never crashes.
///
/// `@MainActor`: `NSImage` isn't `Sendable`, and every caller
/// (menu bar, Settings, Dock icon) is already main-actor, so
/// isolating the cache keeps the release build's strict
/// concurrency check happy without an `unsafe` escape hatch.
@MainActor
enum BrandAssets {
    /// The menu-bar mark: an 18 pt two-rep TIFF (1x + 2x)
    /// from `logo_mono.svg`, flagged as a template so macOS
    /// tints it to match the menu-bar appearance and pressed
    /// state.
    static let menuBarIcon: NSImage? = {
        guard
            let image = Bundle.module.image(
                forResource: "MenuBarIcon"
            )
        else { return nil }
        image.isTemplate = true
        image.accessibilityDescription = L(
            "brand.menu_bar_icon.a11y",
            "KiwiDesk"
        )
        return image
    }()

    /// The vertical wordmark (mark + name + tagline) from
    /// `logo_wordmark.svg`, shown in Settings ▸ General ▸
    /// About in light mode.
    static let wordmark: NSImage? =
        Bundle.module.image(forResource: "Wordmark")

    /// Dark-mode wordmark from `logo_wordmark_dark.svg`: the
    /// kiwi mark is byte-identical to the light master and only
    /// the lettering flips to the brand mist-green, so it reads
    /// on a dark pane without a badge (#479 — before that, the
    /// dark variant re-hued the whole logo to gold). The About
    /// view swaps by `colorScheme`, so neither mode needs a
    /// backing card.
    static let wordmarkDark: NSImage? =
        Bundle.module.image(forResource: "WordmarkDark")

    /// The full-colour app mark from `logo.svg`, in **both**
    /// appearances. Three uses: the Settings sidebar identity
    /// header, and the runtime Dock icon
    /// (`NSApp.applicationIconImage`) so the bare executable
    /// shows the real logo whenever it raises to `.regular`. The
    /// Dock use is an interim stand-in until the packaged `.app`
    /// ships an `.icns` (#89); harmless once the bundle provides
    /// one.
    ///
    /// There is deliberately **no dark variant** (#479). A mark
    /// that changes hue per appearance reads as a different
    /// brand; the mark holds its kiwi green and only the
    /// wordmark's *ink* is themed, which is a legibility problem
    /// on text rather than a hue problem on the symbol. The
    /// retired `AppMarkDark` was a gold recolour of the whole
    /// mark, predating the green-forward palette (#439).
    static let appMark: NSImage? =
        Bundle.module.image(forResource: "AppMark")
}
