import AppKit

/// Bundled brand images (#68 §3.8/§3.9), rasterized from the
/// vector masters in `assets/` (see `assets/README.md` for
/// the regeneration commands). Every accessor is optional — a
/// missing resource falls back to the SF Symbol placeholder
/// at the call site, never crashes.
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
        image.accessibilityDescription = "KiwiDesk"
        return image
    }()

    /// The vertical wordmark (mark + name + tagline) from
    /// `logo_wordmark.svg`, shown in Settings ▸ General ▸
    /// About.
    static let wordmark: NSImage? =
        Bundle.module.image(forResource: "Wordmark")
}
