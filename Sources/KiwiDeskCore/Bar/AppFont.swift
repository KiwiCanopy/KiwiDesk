import AppKit
import CoreText

/// The vendored SketchyBar App Font (#294): process-scoped
/// registration plus font access. Assets live in
/// `Resources/AppFont/` (see its `UPSTREAM.md`); refresh them
/// with `scripts/update-app-font.sh`, never by hand.
public enum AppFont {
    /// PostScript name of the vendored glyph font.
    public static let fontName = "sketchybar-app-font"

    /// One-shot process-scope registration. `.process` scope
    /// shadows nothing outside the app — no user install, no
    /// Font Book entry, no conflict with a copy the user
    /// already installed for sketchybar itself.
    static let registered: Bool = {
        guard
            let url = Bundle.module.url(
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
