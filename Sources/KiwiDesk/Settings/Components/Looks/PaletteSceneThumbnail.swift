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

    /// Whether the draft draws the shelf's border (#1679): the
    /// panel rims its bar plates only then, as the live shelf does.
    /// No default, so a call site cannot drop the draft's switch.
    let drawsBorder: Bool

    /// The draft's `border.sheen` strength (#1644), 0 for none. No
    /// default, like `drawsBorder`.
    let drawsSheen: CGFloat

    /// Whether this drawing paints the sheen: the draft's switch,
    /// at `.panel` only. A 1–2 pt ramp on a 72 pt tile is under a
    /// pixel of lift, so it is a fact the thumbnail cannot render
    /// and is left undrawn there (gui.md ▸ #753).
    var sheens: Bool { drawsSheen != 0 && scene == .panel }

    /// A stroke's paint for `path`: Core's ramp (#702, via
    /// `SheenPaint`) while `sheens`, else the flat colour.
    func sheened(_ path: String) -> AnyShapeStyle {
        guard sheens else { return AnyShapeStyle(color(path)) }
        return SheenPaint.style(hex(path), sheen: drawsSheen)
    }

    /// The palette's hex for `path`, the shipped default beneath;
    /// an Automatic follower reads the colour it follows (#1856).
    func hex(_ path: String) -> String {
        ColorPaletteKeys.resolved(
            path,
            in: Self.fallback.merging(palette.colors) { $1 }
        )
    }

    /// The panel's bar-plate rim: the palette's border colour
    /// while the draft draws a border, else none.
    var borderRim: Color? {
        drawsBorder ? color("kiwishelf.border_color") : nil
    }

    private static let fallback = ColorPaletteKeys.extract(
        from: TilingSettings()
    )

    /// Resolves color path, handling automatic mark tints
    /// (`PaletteSceneThumbnail+Panel`, `Color.kiwiMark`,
    /// `ColorPaletteKeys.allowsAutomatic`).
    func color(_ path: String) -> Color {
        let hex = self.hex(path)
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
            .fill(color("kiwishelf.fill_color"))
            .frame(height: 16 * scale)
            .overlay(
                HStack(spacing: 4 * scale) {
                    pill(color("kiwishelf.item_color"))
                    pill(color("kiwishelf.active_item_color"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 2 * scale)
                                .stroke(

                                    color("kiwishelf.highlight_color"),
                                    lineWidth: 1 * scale
                                )
                        )
                    pill(color("kiwishelf.item_color").opacity(0.6))
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
