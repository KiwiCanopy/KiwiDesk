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

    /// How many slots the row draws — screens, or screens plus
    /// the "+N" chip. The chip takes a slot of its own
    /// (`docs/ui-patterns.md` ▸ "+N"), which is what makes
    /// `hidden` never equal 1.
    static let slots = 4
    /// The small mount of the shared outline. `PresetScreenCard`
    /// draws the large one; the RATIO is what keeps them reading
    /// as one picture, so a change to either is a change to both.
    static let screen = CGSize(width: 20, height: 13)
    static let gap: CGFloat = 3
    static let corner: CGFloat = 3
    static let glyph: CGFloat = 7

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

    /// The fixed leading slot at the shipped grammar, so the
    /// names beside it align down the list. It compares no width,
    /// so it adds no second derivation beside `SettingsWidthClass`.
    static var slotWidth: CGFloat {
        slotWidth(slots: slots, screen: screen, gap: gap)
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
        .frame(width: Self.slotWidth, alignment: .leading)
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
