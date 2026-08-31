import Foundation

/// App icon rendering source for bars (#294).
public enum BarAppIconSource: String, Sendable, Codable, CaseIterable {
    /// The app's native image as macOS provides it (default).
    case appImage = "app_image"
    /// Monochrome ligature glyph from vendored App Font, falling back to icon.
    case appFont = "app_font"
}
