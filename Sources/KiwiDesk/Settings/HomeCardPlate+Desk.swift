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

/// Behavior home card tile previewing mouse divider resize style
/// (`TilingSettings`).
struct HomeCardBehaviorTile: View {
    let settings: TilingSettings
    @Environment(\.schematicPalette) private var palette

    private var resizes: Bool {
        settings.mouseResize == .layout
    }

    var body: some View {
        // Equal panes on purpose: the prototype's 6/4 split was
        // tried via `idealWidth`, which an HStack's concrete
        // proposal never consults — a dead input claiming a
        // ratio the layout ignored (code review, 2026-08-09) —
        // and the divider, not the ratio, is the fact this
        // tile answers with.
        HStack(spacing: 4) {
            pane
            divider
            pane
        }
    }

    private var pane: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(
                palette?.ghostFill
                    ?? SettingsTheme.ink2.opacity(0.08)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(
                        palette?.frame
                            ?? SettingsTheme.ink2.opacity(0.3),
                        lineWidth: 1.5
                    )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var divider: some View {
        let accent =
            resizes
            ? palette?.accent ?? SettingsTheme.accent
            : palette?.ghostStroke
                ?? SettingsTheme.ink2.opacity(0.4)
        return RoundedRectangle(cornerRadius: 1)
            .fill(accent)
            .frame(width: 2)
            .padding(.vertical, 6)
            .overlay(alignment: .top) {
                if resizes { handle(accent) }
            }
            .overlay(alignment: .bottom) {
                if resizes { handle(accent) }
            }
    }

    private func handle(_ accent: Color) -> some View {
        Circle()
            .fill(accent)
            .frame(width: 7, height: 7)
    }
}
