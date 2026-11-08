import KiwiDeskCore
import SwiftUI

/// A Space card's picture (#2777): the Space's layout drawn from
/// the draft in the current look — a hovered look painted on — on
/// the neutral plate, with the Space Bar and this Space lit. Static:
/// nothing in it moves, and it adds no mark Simple cannot reach.
struct SimpleSpacePicture: View {
    @ObservedObject var model: SettingsModel
    let space: SpaceID

    var body: some View {
        let mode = model.config.modes(for: [space])[space] ?? .bsp
        let settings = Self.drawn(model.simplePreviewSettings, in: mode)
        let shown = settings.barVisibilities(in: mode)
        let shape = RoundedRectangle(cornerRadius: 8)
        GeometryReader { geo in
            HomeCardBarsTile(
                settings: settings,
                pocketStands: model.pocketStandsAtRest
                    && !settings.maximizesWindows(in: mode),
                spaceCount: model.config.spaces.count,
                scale: Self.barScale(forWidth: geo.size.width),
                spaceLabels: BarsPanelPreview.spaceLabels(of: model.config),
                activeSpace: model.config.spaces.firstIndex(of: space) ?? 0,
                showsAppBar: shown.app?.showsUnprompted == true,
                wellContent: AnyView(schematic(settings, mode: mode)),
                drawsFrame: false
            )
        }
        .padding(Self.padding)
        .aspectRatio(16.0 / 10.0, contentMode: .fit)
        .deskPlate(settings, in: shape)
        // The menu around it names the layout; the bar strip's own
        // labels are never read.
        .accessibilityHidden(true)
    }

    /// How many windows the picture draws: the schematic's default,
    /// and Floating's whole scatter, which one window would read as
    /// an empty screen.
    nonisolated static func windows(
        for mode: LayoutMode,
        base: Int = LayoutSchematic.defaultWindowCount
    ) -> Int {
        let count = LayoutSchematic.windowCount(base, for: mode)
        return mode == .floating ? max(count, 3) : count
    }

    /// `settings` with the Space Bar as a Space laid out in `mode`
    /// reads it (`barVisibilities(in:)`, #2976), for the tile, which
    /// asks the stored value.
    nonisolated static func drawn(
        _ settings: TilingSettings,
        in mode: LayoutMode
    ) -> TilingSettings {
        var drawn = settings
        drawn.spaceBarStyle.visibility =
            settings.barVisibilities(in: mode)
            .space
        return drawn
    }

    /// The plate's padding around the bars tile.
    static let padding: CGFloat = 6

    /// The bars' scale for a tile `width` wide: the 1.8 the preview
    /// was tuned on at 441.6 pt, in proportion, held at 1 — past it
    /// the App Bar's items add a title their measured length leaves
    /// out, and a card has no room for one anyway.
    static func barScale(forWidth width: CGFloat) -> CGFloat {
        min(1.8 * width / 441.6, 1)
    }

    private func schematic(
        _ settings: TilingSettings,
        mode: LayoutMode
    ) -> some View {
        LayoutSchematicView(
            mode: mode,
            settings: settings.resolved(for: space, activeMode: mode),
            windows: Self.windows(for: mode),
            scale: .tile
        )
        // The well is the screen: no frame or caption of the
        // schematic's own, sized to the well, not past it.
        .environment(\.schematicFillsWell, true)
    }
}
