import KiwiDeskCore
import SwiftUI

/// Static preview thumbnail of a color palette (#375,
/// `ColorPaletteKeys.extract`).
struct PaletteSceneThumbnail: View {
    let palette: ColorPalette
    /// Base height against which internal metrics scale.
    static let baseHeight: CGFloat = 72

    /// Plate corner radius; `PaletteTile` derives padding from this.
    static let plateRadius: CGFloat = 6

    /// Height on the shelf; scales internal elements.
    var height: CGFloat = baseHeight

    /// Which roles this drawing shows (#793, `PaletteSceneRoles`).
    var scene: PaletteSceneScale = .tile

    private static let fallback = ColorPaletteKeys.extract(
        from: TilingSettings()
    )

    /// Resolves color path, handling automatic mark tints
    /// (`PaletteSceneThumbnail+Panel`, `Color.kiwiMark`,
    /// `ColorPaletteKeys.allowsAutomatic`).
    func color(_ path: String) -> Color {
        let hex =
            palette.colors[path] ?? Self.fallback[path] ?? ""
        guard ColorPaletteKeys.allowsAutomatic(path) else {
            return Color(kiwiHex: hex.isEmpty ? "#00000000" : hex)
        }
        return .kiwiMark(hex)
    }

    /// Scaling factor for internal layout.
    var scale: CGFloat {
        switch scene {
        case .tile: return height / Self.baseHeight
        case .panel: return Self.panelScale
        }
    }

    /// Fixed scale factor for the panel scene.
    static let panelScale: CGFloat = 1.9

    /// Computed panel scene height (`PaletteSceneRoleTests`).
    static var panelHeight: CGFloat {
        (10 + 20 + 7 + 30 + 7 + 22 + 7 + 10 + 20 + 16)
            * panelScale
    }

    var body: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: Self.plateRadius * scale
            )
            .fill(SettingsTheme.sunken)
            content
                .padding(8 * scale)
        }
        .frame(
            height: scene == .panel ? Self.panelHeight : height
        )
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var content: some View {
        switch scene {
        case .tile: tileScene
        case .panel: panelScene
        }
    }

    private var tileScene: some View {
        VStack(spacing: 6 * scale) {
            barStrip
            HStack(spacing: 6 * scale) {
                window
                ghost
            }
        }
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
