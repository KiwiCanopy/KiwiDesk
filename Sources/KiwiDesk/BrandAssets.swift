import AppKit
import KiwiDeskCore

/// Bundled brand images (#68 §3.8/§3.9). Accessors are optional and
/// fall back to SF Symbol placeholders at call sites.
@MainActor
enum BrandAssets {
    /// Template menu-bar mark from `MenuBarIcon` resource.
    ///
    /// One shared instance, but its description is re-applied per
    /// read: a stored `L()` freezes its locale (#1311). The one
    /// reader is `OnboardingView+Closing`'s menu-bar strip, where
    /// SwiftUI names `Image(nsImage:)` from it.
    static var menuBarIcon: NSImage? {
        guard let image = cachedMenuBarIcon else { return nil }
        image.accessibilityDescription = L(
            "brand.menu_bar_icon.a11y",
            "KiwiDesk"
        )
        return image
    }

    private static let cachedMenuBarIcon: NSImage? = {
        guard
            let image = Bundle.kiwiDeskGui.image(
                forResource: "MenuBarIcon"
            )
        else { return nil }
        image.isTemplate = true
        return image
    }()

    /// Light-mode wordmark for Settings ▸ General ▸ About.
    static let wordmark: NSImage? =
        Bundle.kiwiDeskGui.image(forResource: "Wordmark")

    /// Dark-mode wordmark for Settings ▸ General ▸ About (#479).
    static let wordmarkDark: NSImage? =
        Bundle.kiwiDeskGui.image(forResource: "WordmarkDark")

    /// Full-colour app mark for Settings sidebar identity (#89, #439, #479).
    static let appMark: NSImage? =
        Bundle.kiwiDeskGui.image(forResource: "AppMark")
}
