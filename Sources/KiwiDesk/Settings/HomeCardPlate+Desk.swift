import KiwiDeskCore
import SwiftUI

/// Monitors and Behavior illustration tiles for Home card plates (#786).

/// Monitors home card tile previewing live display arrangement
/// (`MonitorArrangement`, #758).
struct HomeCardMonitorsTile: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.schematicPalette) private var palette

    private static let standBand: CGFloat = 8
    private static let pipFloor: CGFloat = 26

    var body: some View {
        let mainID = PositionalDisplays.liveMainID
        GeometryReader { proxy in
            let layout = MonitorArrangement.layout(
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
        _ layout: MonitorArrangement.Layout,
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
        _ drawn: MonitorArrangement.Drawn,
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

/// Behavior home card tile: the quit grid, laid out by the
/// engine's own `QuitGridLayout` for the draft's target depth —
/// a readout, never a sketch (#1726 took the mouse divider away).
struct HomeCardBehaviorTile: View {
    let settings: TilingSettings
    @Environment(\.schematicPalette) private var palette

    /// Sample windows the readout gathers; enough that a
    /// shallow target depth visibly piles.
    static let sampleCount = 12

    var body: some View {
        GeometryReader { proxy in
            let frames = Self.frames(in: proxy.size, settings: settings)
            ZStack(alignment: .topLeading) {
                ForEach(frames.indices, id: \.self) { index in
                    pane(frames[index])
                }
            }
        }
    }

    /// The engine's placement of the sample, in the tile's space.
    static func frames(
        in size: CGSize,
        settings: TilingSettings
    ) -> [CGRect] {
        let ids = (1...sampleCount).map { WindowID(UInt32($0)) }
        let placed = QuitGridLayout.frames(
            for: ids,
            in: CGRect(origin: .zero, size: size),
            minSize: 6,
            targetDepth: settings.quitGridTargetDepth
        )
        return ids.compactMap { placed[$0] }
    }

    private func pane(_ rect: CGRect) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(
                palette?.ghostFill
                    ?? SettingsTheme.ink2.opacity(0.08)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(
                        palette?.frame
                            ?? SettingsTheme.ink2.opacity(0.3),
                        lineWidth: 1
                    )
            )
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
    }
}
