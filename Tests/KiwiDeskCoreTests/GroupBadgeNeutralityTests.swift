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
    /// The bundled palettes that carried the old default
    /// because nobody chose it for them.
    private static let inheritors: Set<String> = [
        "Kiwi Gold", "Clean Light", "Slate", "True Dark",
    ]

    /// The ones that picked a badge of their own, each with the
    /// reason it is exempt. Listed rather than implied: the two
    /// lists PARTITION the catalog below, so a ninth bundled
    /// palette cannot join without its author saying which kind
    /// it is. A membership list whose complement lives only in a
    /// comment fails open, which is the one thing a guard about
    /// agreement may not do (architect review, 2026-08-24).
    /// No hexes here on purpose: restating a value the resource
    /// owns makes the comment a second copy to forget. The
    /// reason is the part a file cannot state about itself.
    private static let choosers: [String: String] = [
        "Monochrome": "picked this grey for the role FIRST — "
            + "the default followed it, not the other way round",
        "Sunset": "a warm badge echoing the palette temperature",
        "Ultraviolet": "a cool badge, same reason",
        "Kiwi Neon": "the neon showcase's own accent",
    ]

    /// Being LISTED as a chooser is a claim about the palette,
    /// so it is checked: one whose badge quietly drifted back to
    /// the default would otherwise keep its exemption and its
    /// reason string while the claim went false (code review,
    /// 2026-08-24). Monochrome is the interesting member — it
    /// picked this grey before the default did, so it agrees on
    /// the FILL and is a chooser by its INK, which is why the
    /// pair is read rather than the fill alone.
    @Test("A palette listed as a chooser really chose one")
    func choosersDifferFromTheDefault() throws {
        let app = AppBarStyle()
        let authored = PaletteCatalog.authored()
        for (name, reason) in Self.choosers {
            let palette = try #require(
                authored.first { $0.name == name },
                Comment(rawValue: "missing palette \(name)")
            )
            let fill = palette.colors["app_bar.group_badge_color"]
            let ink =
                palette.colors["app_bar.group_badge_text_color"]
            #expect(
                fill != app.groupBadgeColor
                    || ink != app.groupBadgeTextColor,
                Comment(
                    rawValue:
                        "\(name) is listed as choosing its own "
                        + "badge (\(reason)) but now carries the "
                        + "shipped default pair — move it to "
                        + "`inheritors` or restore its choice"
                )
            )
        }
    }

    @Test("Every bundled palette is an inheritor or a chooser")
    func theTwoListsPartitionTheCatalog() {
        let authored = Set(PaletteCatalog.authored().map(\.name))
        let classified = Self.inheritors.union(
            Self.choosers.keys
        )
        let stray = authored.symmetricDifference(classified)
            .sorted()
            .joined(separator: ", ")
        #expect(
            classified == authored,
            Comment(
                rawValue:
                    "a bundled palette is unclassified: \(stray)"
                    + " — say whether its badge inherits the "
                    + "default or chooses a hue, in the same "
                    + "change that adds it"
            )
        )
    }

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
