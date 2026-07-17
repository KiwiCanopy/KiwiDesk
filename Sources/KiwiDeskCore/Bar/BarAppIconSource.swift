import Foundation

/// Where a bar's app icons come from (#294). Stored as
/// `icon_source` in profile JSON; set from Lua via
/// `app_bar.set_icon_source`.
public enum BarAppIconSource: String, Sendable, Codable {
    /// The app's native image, full color (default).
    case appImage = "app_image"
    /// The native image recolored to a monochrome ramp of the
    /// bar's text colors — the iOS/macOS "Tinted" icon look.
    /// Works for every app.
    case tintedImage = "tinted_image"
    /// A monochrome ligature glyph from the vendored SketchyBar
    /// App Font, following the bar's text colors. Apps without
    /// a glyph fall back to the tinted image so the bar stays
    /// monochrome.
    case appFont = "app_font"
}

/// Brightness of `tinted_image` icons (#294): whether the
/// luminance ramp renders icons light (for dark bars) or dark
/// (for light bars). `auto` (default) follows the system
/// appearance the way the system's own Tinted style does —
/// dark mode gets light icons and vice versa.
public enum BarTintAppearance: String, Sendable, Codable {
    case auto
    case light
    case dark
}
