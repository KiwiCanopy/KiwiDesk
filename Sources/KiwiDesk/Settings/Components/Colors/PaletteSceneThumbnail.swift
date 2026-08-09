import KiwiDeskCore
import SwiftUI

/// A small static preview of a palette (#375): a mock bar strip, a
/// ringed window, and a drag ghost swatch, painted in the palette's
/// colors — so the picker shows *composition*, not isolated chips.
/// Takes the palette by value; sparse palettes fall back to the
/// shipped defaults for any color they omit, so a thumbnail always
/// reads as a complete scene.
/// The Colours & Motion page reuses it at a larger `height` as
/// its live "current colours" scene, fed
/// `ColorPaletteKeys.extract(from:)` over the staged config —
/// same drawing, so the shelf and the page can never disagree
/// about what a palette paints.
struct PaletteSceneThumbnail: View {
    let palette: ColorPalette
    /// The height every internal metric is expressed against.
    /// Named, because `scale` divides by it: restating 72 in
    /// both places would silently rescale the whole drawing by
    /// the wrong factor the day the tile is retuned.
    static let baseHeight: CGFloat = 72

    /// The plate's corner at `baseHeight`. `PaletteTile` derives
    /// its padding from this so the tile's frame and the plate
    /// inside it stay concentric — nested rounds that are not
    /// read as a mistake, and the relation cannot break by
    /// retuning either number alone.
    static let plateRadius: CGFloat = 6

    /// Tile height on the shelf; the page-level scene passes a
    /// larger one. Every element inside is laid out relative to
    /// the frame, so one number scales the whole picture.
    var height: CGFloat = baseHeight

    private static let fallback = ColorPaletteKeys.extract(
        from: TilingSettings()
    )

    private func color(_ path: String) -> Color {
        Color(
            kiwiHex: palette.colors[path]
                ?? Self.fallback[path] ?? "#00000000"
        )
    }

    /// Everything inside is expressed against the shelf tile's
    /// 72 pt, so one `height` scales the whole scene rather than
    /// stretching a fixed drawing inside a taller box.
    private var scale: CGFloat { height / Self.baseHeight }

    var body: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: Self.plateRadius * scale
            )
            .fill(SettingsTheme.sunken)
            VStack(spacing: 6 * scale) {
                barStrip
                HStack(spacing: 6 * scale) {
                    window
                    ghost
                }
            }
            .padding(8 * scale)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }

    /// A mock bar: three pills on the box plate — inactive,
    /// active (accent), and a plain one.
    private var barStrip: some View {
        RoundedRectangle(cornerRadius: 4 * scale)
            .fill(color("app_bar.fill_color"))
            .frame(height: 16 * scale)
            .overlay(
                HStack(spacing: 4 * scale) {
                    pill(color("app_bar.item_color"))
                    pill(color("app_bar.active_item_color"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 2 * scale)
                                .stroke(

                                    color("app_bar.highlight_color"),
                                    lineWidth: 1 * scale
                                )
                        )
                    pill(color("app_bar.item_color").opacity(0.6))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 4 * scale)
            )
    }

    private func pill(_ fill: Color) -> some View {
        RoundedRectangle(cornerRadius: 2 * scale)
            .fill(fill)
            .frame(width: 14 * scale, height: 8 * scale)
    }

    /// A mock focused window wearing its focus ring.
    private var window: some View {
        RoundedRectangle(cornerRadius: 4 * scale)
            .fill(SettingsTheme.hairline)
            .overlay(
                RoundedRectangle(cornerRadius: 4 * scale)
                    .stroke(
                        color("border.focused_color"),
                        lineWidth: 2 * scale
                    )
            )
            .frame(maxWidth: .infinity)
            .frame(height: 24 * scale)
    }

    /// The drag ghost swatch.
    private var ghost: some View {
        RoundedRectangle(cornerRadius: 4 * scale)
            .fill(color("drag.ghost.fill_color"))
            .overlay(
                RoundedRectangle(cornerRadius: 4 * scale)
                    .stroke(
                        color("drag.ghost.border_color"),
                        lineWidth: 2 * scale
                    )
            )
            .frame(width: 26 * scale, height: 24 * scale)
    }
}
