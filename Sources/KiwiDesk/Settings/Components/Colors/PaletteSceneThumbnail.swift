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

    /// Which roles this drawing shows (#793). A **scale**, not a
    /// height threshold: what changes between the two is which
    /// colours are on the frame, and `PaletteSceneRoles` is the
    /// one census of that. The default keeps every existing call
    /// site — the shelf's tiles — exactly as it was.
    var scene: PaletteSceneScale = .tile

    private static let fallback = ColorPaletteKeys.extract(
        from: TilingSettings()
    )

    /// Internal, not private: `PaletteSceneThumbnail+Panel` draws
    /// the full scene from the same lookup, so a sparse palette
    /// falls back identically at both scales.
    ///
    /// A path whose empty value means **Automatic** rather than
    /// unset resolves through `Color.kiwiMark` — derived from
    /// `ColorPaletteKeys.allowsAutomatic` rather than a list of
    /// the two paths here, so a third adaptive mark joins by
    /// existing. Without it the sticky and floating marks drew
    /// as holes at their shipped defaults, both being empty.
    func color(_ path: String) -> Color {
        let hex =
            palette.colors[path] ?? Self.fallback[path] ?? ""
        guard ColorPaletteKeys.allowsAutomatic(path) else {
            return Color(kiwiHex: hex.isEmpty ? "#00000000" : hex)
        }
        return .kiwiMark(hex)
    }

    /// Everything inside is expressed against the shelf tile's
    /// 72 pt, so one `height` scales the whole scene rather than
    /// stretching a fixed drawing inside a taller box.
    /// Internal for the same reason `color` is — the panel scene
    /// expresses its own metrics against it.
    ///
    /// **Only the tile derives it from `height`.** That
    /// "one number scales the whole picture" trick works while
    /// the picture is three rows tall; the panel scene stacks
    /// seven, so deriving 300/72 = 4.17 asked for a 538 pt
    /// drawing inside a 300 pt frame and it spilled over the
    /// diff list beneath it (owner, on device, 2026-08-16). The
    /// panel therefore fixes its own unit and lets its HEIGHT
    /// follow, which is the opposite dependency.
    var scale: CGFloat {
        switch scene {
        case .tile: return height / Self.baseHeight
        case .panel: return Self.panelScale
        }
    }

    /// The panel scene's unit. Chosen so the whole composition
    /// fits the panel column's width at a legible size — the
    /// badges are the floor, at 8 × this.
    static let panelScale: CGFloat = 1.9

    /// What the panel scene actually needs, in points: the sum
    /// of its rows and their gaps at `panelScale`, so the frame
    /// is derived from the drawing rather than asserted over it.
    /// `PaletteSceneRoleTests` holds it against the panel
    /// column's own budget.
    static var panelHeight: CGFloat {
        // Each bar carries a name above it (7 pt + a 3 pt gap),
        // then: strip + gap + windows + gap + drag + gap +
        // strip, then the plate's padding top and bottom.
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
