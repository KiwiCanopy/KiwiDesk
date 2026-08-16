import KiwiDeskCore
import SwiftUI

/// A preset's thumbnail (#678 turn 13a): **one outline per
/// screen**, not one tile per space.
///
/// The old thumbnail drew a tile per space, which reads at four
/// and turns into a row of identical stamps at ten — and a
/// three-screen preset's whole point is *which screen gets what*,
/// which a flat run of tiles cannot say at any count. Screens are
/// the thing that stays legible from one screen to three, so the
/// picture draws screens and the count of spaces goes underneath
/// as text.
///
/// Each outline carries the glyph of its screen's FIRST space —
/// the layout that screen opens on. That is a deliberate part of
/// the preset's plan rather than a sample: `spaceScreens` orders
/// the spaces per screen, and the first one is what a user lands
/// in when the preset applies.
struct PresetScreenCard: View {
    let layout: StandardLayout
    /// The live screens, when this card is one the user can
    /// actually apply — `nil` in the "For other setups" drawer,
    /// where the plan is drawn for a screen COUNT and there is no
    /// hardware to resolve it against.
    ///
    /// Without this the card drew the historic `bsp` for an
    /// unlisted first space while `ProfileComposition.compose`
    /// answered the same space from the display it lands on, so
    /// the three appliable multi-screen presets named a layout
    /// Apply never produces (code review, 2026-08-11).
    var liveSizes: [CGSize]?

    /// #789 grew these from 34×22. The consult that ruled on it
    /// REFUSED drawing a `LayoutSchematicView` in here instead:
    /// the card draws one mode per screen — the first space's
    /// opening mode — which is exactly what the glyph already
    /// encodes, so a schematic would be ~9× the pixels for no
    /// extra discrimination between catalog entries, at a scale
    /// (≈0.43 of `.tile`, half the shipped floor
    /// `HomeCardSchematicBand` uses) where the family's 1 pt and
    /// 2 pt strokes stop rendering. The pixels the bigger card
    /// buys go to the glyph instead.
    private static let outline = CGSize(width: 48, height: 30)
    /// Grown with the outline, so the glyph keeps its share of
    /// the frame rather than shrinking inside a larger one.
    private static let glyphSize: CGFloat = 14

    /// Clamped at zero: a hand-edited layout claiming a negative
    /// screen count must not trap on the range.
    private var screens: Range<Int> {
        0..<max(layout.screenCount, 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                ForEach(screens, id: \.self) { screen in
                    outlineView(screen)
                }
            }
            Text(spaceCountText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// One noun, one pair of keys: the profile row counts spaces
    /// with `profiles.spaces.*` and so does this card. A second
    /// pair with byte-identical English doubles the translation
    /// work and lets the two drift per locale with nothing to
    /// catch it.
    private var spaceCountText: String {
        spaceCountPhrase(layout.spaceCount)
    }

    private func spaceCountPhrase(_ count: Int) -> String {
        count == 1
            ? L("profiles.spaces.one", "1 Space")
            : L("profiles.spaces.many", "%1$d Spaces", count)
    }

    /// An empty screen draws its outline with NO glyph: a layout
    /// mode drawn on a screen the preset plans nothing for is a
    /// claim about behavior that applying it would not produce.
    private func outlineView(_ screen: Int) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(SettingsTheme.accent.opacity(0.12))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(
                        SettingsTheme.hairline
                    )
            }
            .overlay {
                if let mode = openingMode(screen) {
                    Image(systemName: mode.glyph)
                        .font(.system(size: Self.glyphSize))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(
                width: Self.outline.width,
                height: Self.outline.height
            )
            .help(screenHelp(screen))
            // `.help` alone does NOT discharge `screenHelp`'s
            // promise to the reader who cannot see the row: a
            // `Shape` is not an accessibility element, so the
            // hint has nothing to attach to and the sentence is
            // hover-only. Making the outline an element gives
            // VoiceOver the same sentence the pointer gets —
            // which is the whole reason the main display is
            // named in words rather than by position.
            .accessibilityElement()
            .accessibilityLabel(screenHelp(screen))
    }

    /// Screen 0 is the main display, 1 the next secondary, … —
    /// and both the plan and its sparse fallbacks are the
    /// LAYOUT's to answer (`StandardLayout+Screens`), the same
    /// accessors `ProfileComposition.compose` builds a real
    /// profile from. `screens:` is the preset's own screen count,
    /// which is what this card draws: the composer clamps into
    /// the LIVE display list instead, so the two agree exactly
    /// when the preset is appliable — the state its Apply button
    /// requires.
    private func spaces(on screen: Int) -> [SpaceID] {
        layout.spaces(
            onScreen: screen,
            screens: layout.screenCount
        )
    }

    private func openingMode(_ screen: Int) -> LayoutMode? {
        layout.openingMode(
            onScreen: screen,
            screens: layout.screenCount,
            on: shape(of: screen)
        )
    }

    /// The shape of the display this positional screen resolves
    /// to, or nil where the card is not appliable.
    private func shape(of screen: Int) -> ScreenClass? {
        guard let liveSizes, screen < liveSizes.count else {
            return nil
        }
        return ScreenClass.of(liveSizes[screen])
    }

    /// Named for the reader who cannot see the glyph — the count
    /// of spaces on that screen and the layout it opens in. A
    /// screen the preset plans nothing for says so instead of
    /// naming a mode it does not have.
    private func screenHelp(_ screen: Int) -> String {
        guard let mode = openingMode(screen) else {
            return L(
                "presets.screen_help.empty",
                "%1$@: no Spaces",
                screenName(screen)
            )
        }
        // The count phrase, not a `space(s)` parenthetical: the
        // pair already exists for this noun, and the file uses
        // it fourteen lines up.
        return L(
            "presets.screen_help",
            "%1$@: %2$@, opens in %3$@",
            screenName(screen),
            spaceCountPhrase(spaces(on: screen).count),
            mode.displayName
        )
    }

    /// Screen 0 is the main display and the rest are numbered
    /// (#789).
    ///
    /// The card denotes "main" by POSITION — leftmost — which is
    /// a claim a reader who cannot see the row has no way to
    /// recover: every screen announced itself as "Screen N" and
    /// nothing said which one the Mac treats as main. The
    /// alternatives were both refused by the consult that ruled
    /// this: a heavier stroke, because `SettingsTheme+Metrics`
    /// records that weight alone on a hairline was invisible on
    /// device and because stroke weight already carries two
    /// meanings in this window; and a micro-label, which at this
    /// outline size is ~7 pt type. Saying it in words costs no
    /// pixels and removes the inference rather than decorating
    /// it.
    ///
    /// A NAME rather than a branched sentence, so the two frames
    /// above stay one frame each and a locale reorders them
    /// freely.
    ///
    /// **Both arms say "screen", and that is load-bearing.** They
    /// are two alternatives for ONE specifier slot of one frame,
    /// so a pair reading "Main display" / "Screen %1$d" puts two
    /// nouns for one concept in one slot and makes every catalog
    /// reconcile it alone — which all ten duly did, each picking
    /// a different side, while English was the only catalog whose
    /// own pair disagreed (translation audit, 2026-08-16). The
    /// noun is "screen" because this card's own neighbours are:
    /// the group heading counts screens (`presets.for_your.*`),
    /// as do `presets.needs_screens` and `profiles.screens.*`.
    ///
    /// This does NOT settle screen vs display vs monitor for the
    /// repo — `config-vocabulary.md`'s glossary and
    /// `docs/localization-naming.md` are both silent on it while
    /// `en.json` uses all three, which is an owner ruling and a
    /// catalog-wide sweep. It settles this card.
    private func screenName(_ screen: Int) -> String {
        screen == 0
            ? L("presets.screen_name.main", "Main screen")
            : L(
                "presets.screen_name.numbered",
                "Screen %1$d",
                screen + 1
            )
    }
}
