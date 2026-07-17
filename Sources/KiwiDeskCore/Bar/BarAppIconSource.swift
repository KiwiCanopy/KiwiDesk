import Foundation

/// Where a bar's app icons come from (#294). Stored as
/// `icon_source` in profile JSON; set from Lua via
/// `app_bar.set_icon_source`. A synthesized "tinted" source
/// was built and stripped 2026-07-17: the system-wide Icon &
/// widget style already covers that want, and true styled
/// variants are unreachable via public API (#362 tracks the
/// private-path probe).
public enum BarAppIconSource: String, Sendable, Codable {
    /// The app's native image as macOS provides it (default).
    case appImage = "app_image"
    /// A monochrome ligature glyph from the vendored SketchyBar
    /// App Font, following the bar's text colors. Apps without
    /// a glyph keep their native image.
    case appFont = "app_font"
}
