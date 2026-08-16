import SwiftUI

/// A saved profile's screen count, as a row of mini-screens
/// (#789) — the leading slot that used to hold one generic
/// `square.stack.3d.up` glyph identical on every row.
///
/// **Not a plate, deliberately.** `HomeCardPlate.plate(for:)`
/// returns `nil` for `.profiles` because a whole-app card's
/// picture there is a data row rather than a desktop, and taking
/// the fixed-dark `previewPlate` into a list row for a 73 pt
/// ornament would import its whole contract: the `planeRing`
/// seam, a new ink/surface pairing in
/// `SettingsThemeContrastTests`, and concrete inks in place of
/// the hierarchical greys `SettingsFixedGroundTests` bans on the
/// fixed-dark families. So the pips sit on the row's own
/// surface, in the theme's ordinary inks.
///
/// **No accent, either.** The accent marks control FILLS, so
/// accent-filled pips would read as "these ones are selected".
/// The active profile is marked by its `BadgeChip`, which is a
/// text channel rather than a hue — and that badge is also why
/// this row grew no accent FRAME: a framed row inside a framed
/// card is a card-in-card, and the badge already answers.
///
/// **Silent to VoiceOver**, because the count it draws is
/// already spoken by the row's subtitle (`profiles.screens.*`)
/// and announcing the picture too would read one fact twice.
///
/// That is the reason, and it is worth separating from a
/// neighbouring one it was once conflated with: a `.help` on a
/// bare `Shape` is hover-only because a `Shape` is not an
/// accessibility element, which is a fact about `.help`, not an
/// argument for silence. Where such a picture DOES carry a fact
/// of its own, the fix is to make it an element and label it —
/// `PresetScreenCard.outlineView` is the worked case. Here the
/// fact is not its own, so this stays hidden.
struct ProfileScreenPips: View {
    /// The profile's screen count.
    let count: Int

    /// How many slots the row draws — pips, or pips plus the
    /// "+N" chip. The chip takes a slot of its own
    /// (`docs/ui-patterns.md` ▸ "+N"), which is what makes
    /// `hidden` never equal 1: at exactly this many screens the
    /// last slot draws the screen itself rather than a chip
    /// claiming to hide one.
    static let slots = 4
    static let pip = CGSize(width: 18, height: 12)
    static let gap: CGFloat = 3

    /// The grammar itself, as a function of its inputs rather
    /// than of the shipped constants.
    ///
    /// Parameterized deliberately: with `slots` a `static let`,
    /// no assertion over the shipped values can tell a
    /// derivation from a literal that happens to agree with it
    /// today — `slotWidth` was `{ 81 }` for a guard-prover run
    /// and all seven tests stayed green, because the test
    /// restated the same formula and so could only ever mirror
    /// it. Taking the inputs lets the suite assert known widths
    /// at slot counts this app does not ship, which a literal
    /// cannot satisfy.
    static func slotWidth(
        slots: Int,
        pip: CGSize,
        gap: CGFloat
    ) -> CGFloat {
        CGFloat(slots) * pip.width + CGFloat(slots - 1) * gap
    }

    /// The fixed leading slot at the shipped grammar — a
    /// hand-written width is how a cap change silently starts
    /// clipping. Fixed rather than fluid so the names beside it
    /// align down the list; it compares no width, so it adds no
    /// second derivation beside `SettingsWidthClass`.
    static var slotWidth: CGFloat {
        slotWidth(slots: slots, pip: pip, gap: gap)
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
            ForEach(0..<shown, id: \.self) { _ in screenPip }
            if hidden > 0 { moreChip }
        }
        .frame(width: Self.slotWidth, alignment: .leading)
        .accessibilityHidden(true)
    }

    private var screenPip: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(SettingsTheme.ink3.opacity(0.18))
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(SettingsTheme.hairline)
            }
            .frame(
                width: Self.pip.width,
                height: Self.pip.height
            )
    }

    /// Counts the screens NOT drawn, never the total.
    private var moreChip: some View {
        Text(verbatim: "+\(hidden)")
            .font(.system(size: 9, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(SettingsTheme.ink3)
            .frame(
                width: Self.pip.width,
                height: Self.pip.height
            )
    }
}
