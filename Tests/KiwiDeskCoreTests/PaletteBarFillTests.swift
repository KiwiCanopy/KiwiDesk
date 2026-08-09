import Foundation
import Testing

@testable import KiwiDeskCore

/// One bar-fill alpha across everything KiwiDesk ships (#755).
///
/// A palette picks hues; how solid the bars read is not a
/// per-theme preference, and before this the bundled set spread
/// from 40% to 85% — switching palette changed how legible the
/// App Bar and Space Bar were, over any wallpaper. The shipped
/// alpha lives HERE rather than in prose (it is the one number
/// #755 chose), and every bar fill THIS SUITE reaches is derived
/// from it rather than restated: a palette that retunes its own
/// fill reds, and so does a change to either shipped default.
/// Scoped honestly — `docs/lua-reference.md` also states the hex,
/// legitimately, a reference doc's contract being the default
/// value itself, and nothing scans docs.
///
/// Scope is the bar fill alone. Item, hover, badge and border
/// alphas are each their own decision — `space_bar.item_color`
/// at `99` IS the dimmed inactive tier — so nothing here reads
/// them.
@Suite("Palette bar fill")
struct PaletteBarFillTests {
    /// The two bar-fill paths, named once.
    private static let fillPaths = [
        "app_bar.fill_color",
        "space_bar.fill_color",
    ]

    private func alpha(_ hex: String) -> Double? {
        DragVisual.parseHex(hex)?.alpha
    }

    /// The shipped default is the source of the number every
    /// other assertion below derives from — 0xB3, 70%.
    @Test("The shipped bar fill is 70% opaque")
    func shippedDefaultAlpha() throws {
        let settings = TilingSettings()
        let app = try #require(
            alpha(settings.appBarStyle.fillColor)
        )
        #expect(abs(app - Double(0xB3) / 255) < 0.001)
        // Both bars are one surface to the eye, so they carry
        // one fill outright — not merely one alpha.
        #expect(
            settings.spaceBarStyle.fillColor
                == settings.appBarStyle.fillColor
        )
    }

    /// Every bundled palette that sets a bar fill sets it at the
    /// shipped alpha. Derived from `TilingSettings()`, so this
    /// cannot agree with a stale prose copy of the number.
    @Test("Every bundled bar fill carries the shipped alpha")
    func bundledFillsShareTheAlpha() throws {
        let target = try #require(
            alpha(TilingSettings().appBarStyle.fillColor)
        )
        // The catalog has to have loaded at all: a broken
        // resource lookup leaves `bundled()` holding only the
        // derived default, and every count below still adds up
        // because it is derived from the same short list.
        #expect(!PaletteCatalog.authored().isEmpty)
        var seen = 0
        for palette in PaletteCatalog.bundled() {
            for path in Self.fillPaths {
                guard let hex = palette.colors[path] else {
                    continue
                }
                let a = try #require(
                    alpha(hex),
                    Comment(rawValue: "\(palette.name) \(path)")
                )
                #expect(
                    abs(a - target) < 0.001,
                    Comment(
                        rawValue:
                            "\(palette.name) \(path) = \(hex)"
                    )
                )
                seen += 1
            }
        }
        // A scan that read nothing passes for having found no
        // violations. Nine palettes, two bars each.
        #expect(seen == PaletteCatalog.bundled().count * 2)
    }

    /// Within a palette the two bars are the same surface, so
    /// they carry the same fill — an alpha-only agreement would
    /// let one bar drift to another hue unnoticed.
    @Test("A palette's two bar fills are one colour")
    func bothBarsAgreeWithinAPalette() throws {
        #expect(!PaletteCatalog.authored().isEmpty)
        for palette in PaletteCatalog.bundled() {
            let app = try #require(
                palette.colors["app_bar.fill_color"],
                Comment(rawValue: palette.name)
            )
            let space = try #require(
                palette.colors["space_bar.fill_color"],
                Comment(rawValue: palette.name)
            )
            // As colours, not as spellings — `#2c2c2eb3` is the
            // same plate as `#2C2C2EB3` and must not read as a
            // second one.
            #expect(
                ColorPalette.sameColor(app, space),
                Comment(
                    rawValue: "\(palette.name): \(app) / \(space)"
                )
            )
        }
    }
}
