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
    private static let gap: CGFloat = 4

    /// How many slots the row draws before the "+N" chip takes
    /// one — the SAME cap the small mount uses, because the two
    /// draw one grammar at two sizes and a cap that differed would
    /// make a five-screen profile hide a different number of
    /// screens in the list than on its card.
    private static var slots: Int { ProfileScreenPips.slots }

    /// The pips' chip size scaled by the step the glyph takes
    /// between the mounts, so the chip keeps its share of the
    /// outline exactly as `glyphSize` does.
    private static var moreSize: CGFloat {
        ProfileScreenPips.moreSize
            * (glyphSize / ProfileScreenPips.glyph)
    }

    /// Clamped at zero for readability, not for safety.
    ///
    /// A hand-edited layout claiming a negative screen count must
    /// not trap, and this is NOT what prevents that: deleting this
    /// clamp leaves `PresetScreenCardOverflowTests` fully green,
    /// because `OverflowSplit.shown`'s own `max(count, 0)` and
    /// `hidden`'s clamp already cover it (guard-prover,
    /// 2026-08-17). The load-bearing twin is
    /// `PresetPreviewPlan`'s, which reads identically and whose
    /// removal traps the runner on `0..<(-3)`. The two look alike
    /// and are not alike; said here so the next reader does not
    /// reason from this one as if it were the net.
    private var screenCount: Int { max(layout.screenCount, 0) }

    /// Outlines drawn, and screens hidden behind the chip.
    ///
    /// **The row was uncapped until #859**, while the small mount
    /// has always capped: `screenCount` fed the `ForEach`
    /// directly, so a `Starter` derived from five connected
    /// displays drew five 48 pt outlines — 256 pt of them — inside
    /// a card whose grid minimum is 200. Only `Starter` can reach
    /// it (the seven declared presets are capped by hand at three
    /// screens) but `StarterAllocation`'s own docstring is explicit
    /// that eleven displays gets eleven spaces, so the ceiling is
    /// the desk's, not the catalog's.
    ///
    /// Internal rather than private, and asserted directly: a view
    /// that takes a count and draws a constant satisfies every
    /// substring a source scan can look for while answering
    /// nothing (`LayoutSchematicCountTests`' lesson, which
    /// `ProfileScreenPips` took first).
    var shown: Int {
        OverflowSplit.shown(
            of: screenCount,
            fitting: Self.slots,
            withMarker: Self.slots - 1
        )
    }

    var hidden: Int { max(screenCount - shown, 0) }

    private var screens: Range<Int> { 0..<shown }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: Self.gap) {
                ForEach(screens, id: \.self) { screen in
                    outlineView(screen)
                }
                if hidden > 0 { moreChip }
            }
            Text(spaceCountText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// Counts the screens NOT drawn, never the total — and stays
    /// silent to VoiceOver, because the screen count is already
    /// stated in words directly above every card that draws one
    /// (`presets.for_your.*` for the live group,
    /// `profiles.screens.*` per group in the drawer). Announcing
    /// "+2" beside those would read one fact twice, and "+2" alone
    /// says nothing a reader could act on.
    private var moreChip: some View {
        Text(verbatim: "+\(hidden)")
            .font(.system(size: Self.moreSize, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(SettingsTheme.ink3)
            .frame(
                width: Self.outline.width,
                height: Self.outline.height
            )
            .accessibilityHidden(true)
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

    /// **The card and the sheet read ONE derivation.**
    ///
    /// This card had its own `spaces(on:)`, `openingMode(_:)` and
    /// `shape(of:)` against the plan's until #859's review round.
    /// Both reviewers found the pair independently: the copies were
    /// held together only by an agreement test that recomputed the
    /// shape itself and could not see the card's `private` half, so
    /// a drift in the card's bound or its index passed green. The
    /// plan keeps EMPTY groups precisely so it can serve this card
    /// too — the card draws an outline per screen whether or not
    /// that screen has spaces, and a derivation that filtered could
    /// not answer it.
    ///
    /// Screen 0 is the main display, 1 the next secondary, … — and
    /// both the plan and its sparse fallbacks are the LAYOUT's to
    /// answer (`StandardLayout+Screens`), the same accessors
    /// `ProfileComposition.compose` builds a real profile from.
    private var plan: PresetPreviewPlan {
        PresetPreviewPlan(layout: layout, liveSizes: liveSizes)
    }

    private func spaceCount(on screen: Int) -> Int {
        plan.group(screen: screen)?.slots.count ?? 0
    }

    private func openingMode(_ screen: Int) -> LayoutMode? {
        plan.group(screen: screen)?.openingMode
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
                presetScreenName(screen)
            )
        }
        // The count phrase, not a `space(s)` parenthetical: the
        // pair already exists for this noun and `spaceCountPhrase`
        // above is this file's own use of it.
        return L(
            "presets.screen_help",
            "%1$@: %2$@, opens in %3$@",
            presetScreenName(screen),
            spaceCountPhrase(spaceCount(on: screen)),
            mode.displayName
        )
    }
}
