import AppKit
import CoreText

/// Vendored SketchyBar App Font registration and access (#294).
public enum AppFont {
    /// PostScript name of the vendored glyph font.
    public static let fontName = "sketchybar-app-font"

    /// Process-scope font registration state.
    static let registered: Bool = {
        guard
            let url = Bundle.kiwiDeskCore.url(
                forResource: "sketchybar-app-font",
                withExtension: "ttf",
                subdirectory: "AppFont"
            )
        else { return false }
        // An already-registered error is fine; any real
        // failure surfaces as the nil font check below and
        // callers degrade to native app images.
        CTFontManagerRegisterFontsForURL(
            url as CFURL,
            .process,
            nil
        )
        return NSFont(name: fontName, size: 12) != nil
    }()

    /// The glyph font at `size`, or nil when registration
    /// failed (callers fall back to the native app image).
    public static func font(size: CGFloat) -> NSFont? {
        guard registered else { return nil }
        return NSFont(name: fontName, size: size)
    }
}
