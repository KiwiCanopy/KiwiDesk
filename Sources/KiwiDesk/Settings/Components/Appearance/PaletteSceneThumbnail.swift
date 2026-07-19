import KiwiDeskCore
import SwiftUI

/// A small static preview of a palette (#375): a mock bar strip, a
/// ringed window, and a drag ghost swatch, painted in the palette's
/// colors — so the picker shows *composition*, not isolated chips.
/// Takes the palette by value; sparse palettes fall back to the
/// shipped defaults for any color they omit, so a thumbnail always
/// reads as a complete scene.
struct PaletteSceneThumbnail: View {
    let palette: ColorPalette

    private static let fallback = ColorPaletteKeys.extract(
        from: TilingSettings()
    )

    private func color(_ path: String) -> Color {
        Color(
            kiwiHex: palette.colors[path]
                ?? Self.fallback[path] ?? "#00000000"
        )
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.12))
            VStack(spacing: 6) {
                barStrip
                HStack(spacing: 6) {
                    window
                    ghost
                }
            }
            .padding(8)
        }
        .frame(height: 72)
        .frame(maxWidth: .infinity)
    }

    /// A mock bar: three pills on the box plate — inactive,
    /// active (accent), and a plain one.
    private var barStrip: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(color("app_bar.fill_color"))
            .frame(height: 16)
            .overlay(
                HStack(spacing: 4) {
                    pill(color("app_bar.item_color"))
                    pill(color("app_bar.active_item_color"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(
                                    color("app_bar.highlight_color"),
                                    lineWidth: 1
                                )
                        )
                    pill(color("app_bar.item_color").opacity(0.6))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 4)
            )
    }

    private func pill(_ fill: Color) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(fill)
            .frame(width: 14, height: 8)
    }

    /// A mock focused window wearing its focus ring.
    private var window: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.secondary.opacity(0.18))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        color("border.focused_color"),
                        lineWidth: 2
                    )
            )
            .frame(maxWidth: .infinity)
            .frame(height: 24)
    }

    /// The drag ghost swatch.
    private var ghost: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(color("drag.ghost.fill_color"))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        color("drag.ghost.border_color"),
                        lineWidth: 2
                    )
            )
            .frame(width: 26, height: 24)
    }
}
