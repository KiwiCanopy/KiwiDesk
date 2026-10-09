import KiwiDeskCore
import SwiftUI

/// Screens and Behavior illustration tiles for Home card plates (#786).

/// Screens home card tile previewing live screen arrangement
/// (`ScreenArrangement`, #758).
struct HomeCardScreensTile: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.schematicPalette) private var palette

    private static let standBand: CGFloat = 8
    private static let pipFloor: CGFloat = 26

    var body: some View {
        let mainID = PositionalDisplays.liveMainID
        GeometryReader { proxy in
            let layout = ScreenArrangement.layout(
                displays: model.displays,
                mainID: mainID,
                canvas: proxy.size,
                hostsChips: false
            )
            let shift = centering(layout, in: proxy.size)
            ForEach(layout.displays) { drawn in
                display(
                    drawn,
                    main: drawn.display.id == mainID
                )
                .offset(x: shift.width, y: shift.height)
            }
        }
    }

    /// Computes offset centering display layout union in canvas.
    private func centering(
        _ layout: ScreenArrangement.Layout,
        in canvas: CGSize
    ) -> CGSize {
        let rects = layout.displays.map(\.rect)
        guard let first = rects.first else { return .zero }
        let union = rects.dropFirst().reduce(first) {
            $0.union($1)
        }
        return CGSize(
            width: (canvas.width - union.width) / 2
                - union.minX,
            height: (canvas.height - union.height) / 2
                - union.minY
        )
    }

    @ViewBuilder
    private func display(
        _ drawn: ScreenArrangement.Drawn,
        main: Bool
    ) -> some View {
        let rect = drawn.rect
        let cardHeight = max(rect.height - Self.standBand, 6)
        let stroke =
            main
            ? palette?.accent ?? SettingsTheme.accent
            : palette?.ghostStroke
                ?? SettingsTheme.ink2.opacity(0.6)
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    main
                        ? palette?.fill ?? LayoutSchematic.fill
                        : palette?.ghostFill
                            ?? Color.primary.opacity(0.05)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(
                            stroke,
                            lineWidth: main ? 2 : 1.5
                        )
                )
                .overlay {
                    if main, rect.width >= Self.pipFloor {
                        pips
                    }
                }
                .frame(height: cardHeight)
            neck(width: rect.width)
        }
        .frame(width: rect.width)
        .offset(x: rect.minX, y: rect.minY)
    }

    /// Stand shares from token scaling (#758).
    private func neck(width: CGFloat) -> some View {
        let foot = width * SettingsTheme.monitorStandScale
        return VStack(spacing: 0) {
            Rectangle()
                .fill(
                    palette?.ghostStroke
                        ?? SettingsTheme.ink2.opacity(0.4)
                )
                .frame(
                    width: foot * SettingsTheme.monitorNeckScale,
                    height: 5
                )
            Capsule()
                .fill(
                    palette?.ghostStroke
                        ?? SettingsTheme.ink2.opacity(0.4)
                )
                .frame(width: foot, height: 3)
        }
    }

    private var pips: some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2)
                .fill(palette?.accent ?? SettingsTheme.accent)
                .frame(width: 8, height: 8)
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    palette?.ghostStroke
                        ?? SettingsTheme.ink2.opacity(0.4)
                )
                .frame(width: 8, height: 8)
        }
    }
}
