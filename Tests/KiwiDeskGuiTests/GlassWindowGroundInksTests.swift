import AppKit
import SwiftUI
import Testing

@testable import KiwiDesk

/// `glassWindowGround`'s inks (#3650): where the fallback draws, a
/// descendant's `.primary` / `.secondary` resolve to the inks
/// handed in; on glass they stay the system's. Rendered with
/// marker hues so a pixel says which style drew; the render's
/// colour space shifts a hue a little, so a channel must dominate.
/// `@MainActor` for `ImageRenderer`: four 20 pt renders.
@MainActor
@Suite("Glass window ground inks (#3650)")
struct GlassWindowGroundInksTests {
    /// The centre pixel's RGB of a square filled with `style`.
    private static func centre(
        _ style: some ShapeStyle,
        glass: Bool
    ) throws -> (r: Int, g: Int, b: Int) {
        let view = Rectangle().fill(style)
            .frame(width: 20, height: 20)
            .glassWindowGround(
                enabled: glass,
                variant: .regular,
                fallback: AnyShapeStyle(Color.clear),
                primary: Color(.sRGB, red: 1, green: 0, blue: 0),
                secondary: Color(.sRGB, red: 0, green: 0, blue: 1)
            )
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        let rep = NSBitmapImageRep(cgImage: image)
        let color = try #require(
            rep.colorAt(x: image.width / 2, y: image.height / 2)?
                .usingColorSpace(.sRGB)
        )
        return (
            Int((color.redComponent * 255).rounded()),
            Int((color.greenComponent * 255).rounded()),
            Int((color.blueComponent * 255).rounded())
        )
    }

    @Test("the fallback resolves the hierarchical styles to the inks")
    func fallbackTakesTheInks() throws {
        let primary = try Self.centre(.primary, glass: false)
        #expect(
            primary.r - max(primary.g, primary.b) > 150,
            "primary: \(primary)"
        )
        let secondary = try Self.centre(.secondary, glass: false)
        #expect(
            secondary.b - max(secondary.r, secondary.g) > 150,
            "secondary: \(secondary)"
        )
    }

    /// The negative control: on glass the system's styles draw, a
    /// neutral grey with no marker hue in it. Below macOS 26 the
    /// ground always falls back, so there is no glass to test.
    @Test(
        "glass keeps the system's styles",
        .enabled(if: GlassChromeVariant.drawable)
    )
    func glassKeepsTheSystemStyles() throws {
        for style in [AnyShapeStyle(.primary), AnyShapeStyle(.secondary)] {
            let drawn = try Self.centre(style, glass: true)
            #expect(
                abs(drawn.r - drawn.b) < 8 && abs(drawn.r - drawn.g) < 8,
                "glass drew a marker hue: \(drawn)"
            )
        }
    }
}
