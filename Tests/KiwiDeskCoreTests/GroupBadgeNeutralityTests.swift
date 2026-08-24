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
    /// red and green).
    ///
    /// Eight points is the door, and it is worth being exact
    /// about what that claims: it admits every Apple system grey
    /// with room (`#8E8E93` and `#F2F2F7` span 5, `#1C1C1E` 2)
    /// and nothing anyone would call a hue — the red this
    /// replaced spans 176. It does NOT admit a *tinted* brand
    /// grey: a warm `#8A8A80` spans 10 and reds here despite
    /// reading grey to the eye. That is the intended trade for a
    /// DEFAULT — retuning it toward a temperature should be a
    /// deliberate edit that trips a guard, not a drift.
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
        // Each bar's keys are read against THAT bar's struct.
        // Reading both against the App Bar would have left the
        // Space Bar default with one net — the cross-bar
        // equality above — and a guard with one net is one
        // careless edit from watching nothing (guard-prover,
        // 2026-08-24).
        let app = AppBarStyle()
        let space = SpaceBarStyle()
        let pairs = [
            (
                "app_bar", app.groupBadgeColor,
                app.groupBadgeTextColor
            ),
            (
                "space_bar", space.groupBadgeColor,
                space.groupBadgeTextColor
            ),
        ]
        let authored = PaletteCatalog.authored()
        for name in Self.inheritors {
            let palette = try #require(
                authored.first { $0.name == name },
                Comment(rawValue: "missing palette \(name)")
            )
            for (bar, fill, ink) in pairs {
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
