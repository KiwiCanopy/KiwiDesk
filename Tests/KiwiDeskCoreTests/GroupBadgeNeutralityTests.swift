import Foundation
import Testing

@testable import KiwiDeskCore

/// The count badge's DEFAULT fill is neutral (#955). A group
/// badge counts windows that are simply there, so the shipped
/// default may not wear an alert hue — the notification idiom it
/// borrowed until #955 spent urgency the state does not carry.
/// A theme stays free to pick a hue; this pins the default and
/// the palettes that only ever inherited it.
///
/// Legibility is a separate pin —
/// `SpaceBarAccentSeparationTests.badgeInkClearsContrastOnItsChip`
/// holds the ink against the chip, and it held on the red too.
@Suite("Group badge neutrality")
struct GroupBadgeNeutralityTests {
    /// The four bundled palettes that carried the old default
    /// because nobody chose it for them. The other four
    /// (Monochrome, Sunset, Ultraviolet, Kiwi Neon) picked their
    /// own badge and are deliberately absent.
    private static let inheritors = [
        "Kiwi Gold", "Clean Light", "Slate", "True Dark",
    ]

    /// Near-neutral, not byte-identical channels: Apple's greys
    /// carry a few points of blue (`#636366` is three above its
    /// red and green), and a badge that reads as grey on screen
    /// is the claim. Eight points is a wide enough door for that
    /// and nowhere near wide enough for a hue — the red this
    /// replaced spanned 176.
    private func isGrey(_ hex: String) -> Bool {
        guard let c = ColorVision.components(hex) else {
            return false
        }
        let spread = max(c.r, c.g, c.b) - min(c.r, c.g, c.b)
        return spread <= 8.0 / 255.0
    }

    @Test("Both bars default to one near-neutral badge fill")
    func defaultBadgeIsNeutralOnBothBars() {
        let app = AppBarStyle().groupBadgeColor
        let space = SpaceBarStyle().groupBadgeColor
        #expect(isGrey(app), Comment(rawValue: app))
        #expect(isGrey(space), Comment(rawValue: space))
        // The two bars' badges are one idiom, so they move
        // together or one of them is the odd badge out.
        #expect(app.lowercased() == space.lowercased())
        #expect(
            AppBarStyle().groupBadgeTextColor
                == SpaceBarStyle().groupBadgeTextColor
        )
    }

    @Test("The palettes that inherited the default still do")
    func inheritingPalettesCarryTheDefaultPair() throws {
        let fill = AppBarStyle().groupBadgeColor
        let ink = AppBarStyle().groupBadgeTextColor
        let authored = PaletteCatalog.authored()
        for name in Self.inheritors {
            let palette = try #require(
                authored.first { $0.name == name },
                Comment(rawValue: "missing palette \(name)")
            )
            for bar in ["app_bar", "space_bar"] {
                #expect(
                    palette.colors["\(bar).group_badge_color"]
                        == fill,
                    Comment(rawValue: "\(name) \(bar) fill")
                )
                #expect(
                    palette.colors[
                        "\(bar).group_badge_text_color"
                    ] == ink,
                    Comment(rawValue: "\(name) \(bar) ink")
                )
            }
        }
    }
}
