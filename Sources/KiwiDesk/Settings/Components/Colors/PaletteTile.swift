import KiwiDeskCore
import SwiftUI

/// One tile on the palette shelf (#757): a plate, a name line and
/// a caption line inside one bordered frame.
///
/// Both kinds of tile render through this — a palette card and
/// the trailing "Save current colors as…" add tile — so the two
/// are the same height and the same shape **by construction**.
/// They were not before: the add tile was a bare 72 pt stroke
/// with no text lines under it, which only looked aligned because
/// no palette tile had a frame to compare it against.
///
/// They differ in the frame's PATTERN and nothing else — dashed
/// means "an action, not a thing yet"; solid means "a thing".
/// Same colour, same weight, same radius, so the two read as one
/// grid.
struct PaletteTile<Plate: View>: View {
    /// The name line. On the add tile this is its own label,
    /// which is why the tile takes a string rather than a
    /// palette.
    let name: String
    /// The muted second line ("Built-in"). Absent still draws the
    /// line — an empty caption must not shorten one tile in a row
    /// of them.
    var caption: String?
    /// Draws the applied mark and takes the accent frame.
    var isApplied = false
    /// The add tile's frame.
    var dashed = false
    @ViewBuilder var plate: () -> Plate

    /// The plate's height — the thumbnail's own, so a retune of
    /// the scene drawing carries the add tile with it.
    static var plateHeight: CGFloat {
        PaletteSceneThumbnail.baseHeight
    }

    /// Padding between the frame and the plate. The frame's
    /// radius minus this is the plate's own radius, which is what
    /// makes the two rounds concentric rather than merely nested.
    private static var inset: CGFloat { 6 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            plate()
                .frame(height: Self.plateHeight)
            nameLine
            // A blank line, not a missing one: a user palette has
            // no "Built-in" caption and must still be as tall as
            // the bundled tile beside it.
            Text(caption ?? " ")
                .font(.caption2)
                .foregroundStyle(SettingsTheme.ink3)
                .lineLimit(1)
        }
        .padding(Self.inset)
        .frame(maxWidth: .infinity)
        .overlay(frame)
    }

    /// The applied mark leads the name in a slot that is present
    /// on every tile — empty when unapplied, so names stay
    /// aligned down the grid and only the ink appears.
    ///
    /// A bare `checkmark`, which is this app's "this is the
    /// current value" glyph (`ColorField`'s current-swatch
    /// label). Deliberately NOT `checkmark.circle.fill`: that one
    /// means an action just completed (`FitGapsAction`,
    /// `LoginItemCard`), and being on a palette is a state that
    /// outlives the launch.
    private var nameLine: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(SettingsTheme.ink)
                .opacity(isApplied ? 1 : 0)
                .accessibilityLabel(
                    L("palettes.applied", "Applied")
                )
                .accessibilityHidden(!isApplied)
                .frame(width: 10)
            Text(name)
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    /// Border only, never a fill. The tile's content IS colour,
    /// so a fill would be a third channel competing with the
    /// palette's own picture — and on `page`, under `hairline`,
    /// a `card` fill would put three near-identical greens inside
    /// twenty points of each other.
    private var frame: some View {
        RoundedRectangle(
            cornerRadius: SettingsTheme.disclosureRadius
        )
        .strokeBorder(
            isApplied
                ? AnyShapeStyle(SettingsTheme.accent)
                : AnyShapeStyle(SettingsTheme.hairline),
            style: StrokeStyle(
                lineWidth: isApplied
                    ? SettingsTheme.paletteCardStrokeApplied
                    : SettingsTheme.paletteCardStroke,
                dash: dashed ? [4] : []
            )
        )
    }
}
