import KiwiDeskCore
import SwiftUI

/// Panel-scale palette scene (#793, `PaletteSceneRoles`,
/// `PaletteSceneRoleTests`, `ColorPaletteKeys.all`).
extension PaletteSceneThumbnail {
    var panelScene: some View {
        VStack(spacing: 7 * scale) {
            named(SettingsCatalog.bars.spaceBarCard) {
                spaceBarStrip
            }
            HStack(spacing: 7 * scale) {
                windowTile(
                    ring: color("border.focused_color"),
                    ringWidth: 2.5 * scale,
                    mark: color("sticky.color"),
                    symbol: StickyStyle.symbolName(for: .global)
                )
                windowTile(
                    ring: color("border.unfocused_color"),
                    ringWidth: 1.5 * scale,
                    mark: color("floating.color"),
                    symbol: FloatingStyle.symbolName
                )
            }
            HStack(spacing: 7 * scale) {
                dragTile(
                    fill: color("drag.ghost.fill_color"),
                    border: color("drag.ghost.border_color"),
                    dashed: false
                )
                dragTile(
                    fill: color("drag.drop_zone.fill_color"),
                    border: color("drag.drop_zone.border_color"),
                    dashed: true
                )
            }
            named(SettingsCatalog.bars.appBarCard) {
                appBarStrip
            }
        }
    }

    /// A bar strip under its section header label.
    @ViewBuilder
    private func named<C: View>(
        _ control: SettingsControl,
        @ViewBuilder strip: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: 3 * scale) {
            Text(control.text)
                .font(
                    .system(size: 7 * scale, weight: .semibold)
                )
                .textCase(.uppercase)
                .kerning(0.6)
                .foregroundStyle(SettingsTheme.ink3)
                .lineLimit(1)
                .accessibilityHidden(true)
            strip()
        }
    }

    // MARK: - The two bars

    private var spaceBarStrip: some View {
        barPlate(fill: color("space_bar.fill_color")) {
            item(color("space_bar.item_color"))
            item(
                color("space_bar.active_item_color"),
                highlight: color("space_bar.highlight_color")
            )
            .overlay(alignment: .topTrailing) {
                badge(
                    color("space_bar.group_badge_color"),
                    ink: color("space_bar.group_badge_text_color")
                )
            }
            item(color("space_bar.focused_item_color"))
        }
    }

    private var appBarStrip: some View {
        barPlate(fill: color("app_bar.fill_color")) {
            item(color("app_bar.item_color"))
            item(
                color("app_bar.active_item_color"),
                highlight: color("app_bar.highlight_color")
            )
            .overlay(alignment: .topTrailing) {
                badge(
                    color("app_bar.group_badge_color"),
                    ink: color("app_bar.group_badge_text_color")
                )
            }
            item(color("app_bar.item_color").opacity(0.55))
        }
    }

    private func barPlate<C: View>(
        fill: Color,
        @ViewBuilder items: () -> C
    ) -> some View {
        RoundedRectangle(cornerRadius: 4 * scale)
            .fill(fill)
            .frame(height: 20 * scale)
            .overlay(
                HStack(spacing: 5 * scale) {
                    items()
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 5 * scale)
            )
    }

    private func item(
        _ fill: Color,
        highlight: Color? = nil
    ) -> some View {
        RoundedRectangle(cornerRadius: 2 * scale)
            .fill(fill)
            .frame(width: 18 * scale, height: 10 * scale)
            .overlay {
                if let highlight {
                    RoundedRectangle(cornerRadius: 2 * scale)
                        .stroke(highlight, lineWidth: 1.5 * scale)
                }
            }
    }

    private func badge(_ fill: Color, ink: Color) -> some View {
        Circle()
            .fill(fill)
            .frame(width: 8 * scale, height: 8 * scale)
            .overlay(
                Circle()
                    .fill(ink)
                    .frame(width: 3 * scale, height: 3 * scale)
            )
            .offset(x: 3 * scale, y: -3 * scale)
    }

    // MARK: - Windows and drag visuals

    private func windowTile(
        ring: Color,
        ringWidth: CGFloat,
        mark: Color,
        symbol: String?
    ) -> some View {
        RoundedRectangle(cornerRadius: 4 * scale)
            .fill(SettingsTheme.hairline)
            .overlay(
                RoundedRectangle(cornerRadius: 4 * scale)
                    .stroke(ring, lineWidth: ringWidth)
            )
            .overlay(alignment: .topLeading) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(
                            .system(size: 9 * scale, weight: .bold)
                        )
                        .foregroundStyle(mark)
                        .padding(4 * scale)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 30 * scale)
    }

    /// Ghost and drop zone comparison tile (#231).
    private func dragTile(
        fill: Color,
        border: Color,
        dashed: Bool
    ) -> some View {
        RoundedRectangle(cornerRadius: 4 * scale)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: 4 * scale)
                    .stroke(
                        border,
                        style: StrokeStyle(
                            lineWidth: 2 * scale,
                            dash: dashed ? [3 * scale] : []
                        )
                    )
            )
            .frame(maxWidth: .infinity)
            .frame(height: 22 * scale)
    }
}
