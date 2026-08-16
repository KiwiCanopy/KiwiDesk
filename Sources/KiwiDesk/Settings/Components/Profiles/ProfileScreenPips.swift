import KiwiDeskCore
import SwiftUI

/// A saved profile's screens, drawn in the SAME grammar as
/// `PresetScreenCard` (#789) — one outline per screen, each
/// carrying the glyph of what that screen opens in.
///
/// **The grammar is the point.** The saved list and the preset
/// grid answer one question — "what shape is this profile?" — and
/// before this they answered it two ways in one scroll: featureless
/// grey rectangles up top, outlined screens with layout glyphs
/// below. They are the same object at different ages (the design
/// digest's own phrase), so they draw the same picture at two
/// sizes. `PresetScreenCard.outline` is the large mount; this is
/// the small one, and both take their fill, stroke and radius from
/// the shared constants below.
///
/// **A screen with no answer draws its outline and no glyph**, the
/// rule the preset card already draws by. A stored profile can say
/// less than a preset: it pins spaces to fingerprints rather than
/// to positions, and which monitor is Main is resolved live, so a
/// multi-screen profile whose spaces were never pinned genuinely
/// does not say. `Profile.openingModes()` owns that reasoning and
/// returns `nil` there rather than guessing.
///
/// **Not a plate, and no accent.** `HomeCardPlate.plate(for:)`
/// returns `nil` for `.profiles` — a whole-app card's picture here
/// is a data row, not a desktop — and the accent marks control
/// FILLS, so accent-filled screens would read as "these ones are
/// selected". The active profile is marked by its `BadgeChip`,
/// which is a text channel. A consult proposed an accent-tinted
/// tile for the active row (2026-08-16) and it was refused twice
/// over: it separated active from inactive by hue at one weight,
/// which is what `paletteCardStroke`'s 1→2 step exists to prevent,
/// and its two ground tints measured ~3% apart in luminance —
/// invisible to everyone, CVD or not.
///
/// **Silent to VoiceOver**: the count is already in the row's
/// subtitle and each screen's mode is not a fact the row claims,
/// so announcing the picture would read one fact twice.
struct ProfileScreenPips: View {
    /// The profile's screen count.
    let count: Int
    /// What each screen opens in, in the stored set's own order —
    /// `nil` per screen where the profile does not say. Short or
    /// empty is legal and draws bare outlines.
    var openingModes: [LayoutMode?] = []
    /// How many slots the row RESERVES — the widest profile in
    /// the list, capped at `slots`.
    ///
    /// Passed in because alignment is a property of the LIST, not
    /// of a row: the names line up only if every row reserves the
    /// same width, and reserving the CAP instead stranded a
    /// one-screen profile's single outline ~69 pt from its own
    /// name on a list where nothing had four screens (owner
    /// eye-confirm, 2026-08-16). Reserving the widest row keeps
    /// the alignment and spends nothing on screens no profile
    /// has.
    var reservedSlots: Int = slots

    /// How many slots the row draws — screens, or screens plus
    /// the "+N" chip. The chip takes a slot of its own
    /// (`docs/ui-patterns.md` ▸ "+N"), which is what makes
    /// `hidden` never equal 1.
    static let slots = 4
    /// The small mount of the shared outline. `PresetScreenCard`
    /// draws the large one (48×30, glyph 14); the RATIO is what
    /// keeps them reading as one picture, so a change to either
    /// is a change to both.
    ///
    /// This is ~71% of the card, and it was 42% for one build:
    /// at 20×13 with a 7 pt glyph the row read as a DIFFERENT
    /// thing rather than the same thing smaller, which is the
    /// one job this picture has (owner eye-confirm,
    /// 2026-08-16). 34×22 is what the card itself drew before
    /// #789 grew it, so the pair is now "the card, and the card
    /// one size down" rather than two unrelated sizes.
    ///
    /// The ceiling on growing it further is the ROW, not taste:
    /// the text block beside it is a headline over a caption,
    /// about 32 pt, and a picture taller than that sets the
    /// list's row height instead of fitting inside it.
    static let screen = CGSize(width: 34, height: 22)
    static let gap: CGFloat = 3
    static let corner: CGFloat = 3
    static let glyph: CGFloat = 12

    /// The grammar, as a function of its inputs rather than of
    /// the shipped constants — with `slots` a `static let`, no
    /// assertion over the shipped values can tell a derivation
    /// from a literal that agrees with it today.
    static func slotWidth(
        slots: Int,
        screen: CGSize,
        gap: CGFloat
    ) -> CGFloat {
        CGFloat(slots) * screen.width + CGFloat(slots - 1) * gap
    }

    /// This row's reserved width — the grammar at whatever the
    /// LIST reserved. It compares no width, so it adds no second
    /// derivation beside `SettingsWidthClass`.
    var slotWidth: CGFloat {
        Self.slotWidth(
            slots: max(1, min(reservedSlots, Self.slots)),
            screen: Self.screen,
            gap: Self.gap
        )
    }

    /// What a list reserves for a set of profiles: the widest
    /// one, capped, and never less than one slot — a list whose
    /// profiles all claim zero screens still reserves a column so
    /// the names do not jump when one is added.
    static func reservedSlots(
        forScreenCounts counts: some Collection<Int>
    ) -> Int {
        max(1, min(counts.max() ?? 1, slots))
    }

    /// Internal rather than private, and asserted directly: a
    /// view that takes a count and draws a constant satisfies
    /// every substring a source scan can look for while
    /// answering nothing (`LayoutSchematicCountTests`' lesson).
    var shown: Int {
        OverflowSplit.shown(
            of: count,
            fitting: Self.slots,
            withMarker: Self.slots - 1
        )
    }

    var hidden: Int { max(count - shown, 0) }

    var body: some View {
        HStack(spacing: Self.gap) {
            ForEach(0..<shown, id: \.self) { index in
                screenOutline(mode(at: index))
            }
            if hidden > 0 { moreChip }
        }
        .frame(width: slotWidth, alignment: .leading)
        .accessibilityHidden(true)
    }

    /// Bounds-checked rather than assumed: `openingModes` comes
    /// from a stored file, and a hand-edited profile whose set
    /// disagrees with its monitor count must draw a bare outline,
    /// not trap.
    private func mode(at index: Int) -> LayoutMode? {
        guard index < openingModes.count else { return nil }
        return openingModes[index]
    }

    private func screenOutline(_ mode: LayoutMode?) -> some View {
        RoundedRectangle(cornerRadius: Self.corner)
            .fill(SettingsTheme.accent.opacity(0.12))
            .overlay {
                RoundedRectangle(cornerRadius: Self.corner)
                    .strokeBorder(SettingsTheme.hairline)
            }
            .overlay {
                if let mode {
                    Image(systemName: mode.glyph)
                        .font(.system(size: Self.glyph))
                        .foregroundStyle(SettingsTheme.ink3)
                }
            }
            .frame(
                width: Self.screen.width,
                height: Self.screen.height
            )
    }

    /// Counts the screens NOT drawn, never the total.
    private var moreChip: some View {
        Text(verbatim: "+\(hidden)")
            .font(.system(size: 9, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(SettingsTheme.ink3)
            .frame(
                width: Self.screen.width,
                height: Self.screen.height
            )
    }
}
