import KiwiDeskCore
import SwiftUI

/// The desk tiles of the Home card plates (#786): Monitors
/// and Behaviour. Split from HomeCardPlate+Scene.swift at
/// the file-size ceiling; the container, palette and
/// dispatch stay in HomeCardPlate.swift.

/// The Monitors picture, small: the real display set through
/// the one arrangement maths (`MonitorArrangement.layout`,
/// chip-less), CENTRED in the plate — the layout anchors its
/// union at the origin, which read as a lone display shoved
/// into a corner (owner, 2026-08-09). Each display sits on a
/// stand derived from the #758 share tokens — shares only; the
/// point clamps belong to the area picture's card sizes — with
/// the main display in the palette accent carrying two window
/// pips where its card has room for them.
struct HomeCardMonitorsTile: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.schematicPalette) private var palette

    /// The mini stand band under each display card.
    private static let standBand: CGFloat = 8
    /// Below this card width the pips are dropped, not clipped
    /// — a thumbnail drops a fact it has no room to render.
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

    /// The delta that centres the drawn union in the canvas.
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
                ?? Color.secondary.opacity(0.6)
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

    /// Stand shares from the #758 tokens, unclamped: the mini
    /// display is far below `monitorStandMin`, where the floor
    /// would draw a plinth wider than the screen.
    private func neck(width: CGFloat) -> some View {
        let foot = width * SettingsTheme.monitorStandScale
        return VStack(spacing: 0) {
            Rectangle()
                .fill(
                    palette?.ghostStroke
                        ?? Color.secondary.opacity(0.4)
                )
                .frame(
                    width: foot * SettingsTheme.monitorNeckScale,
                    height: 5
                )
            Capsule()
                .fill(
                    palette?.ghostStroke
                        ?? Color.secondary.opacity(0.4)
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
                        ?? Color.secondary.opacity(0.4)
                )
                .frame(width: 8, height: 8)
        }
    }
}

/// The Behaviour picture (owner ruled the prototype's pictogram
/// in, 2026-08-09), made honest: two panes with the divider the
/// mouse drags between them. The divider answers the REAL
/// mouse-resize choice — accented with drag handles while a
/// drag resizes neighbours, a quiet ghost while it snaps back —
/// so the tile derives from the draft like every other plate.
struct HomeCardBehaviorTile: View {
    let settings: TilingSettings
    @Environment(\.schematicPalette) private var palette

    private var resizes: Bool {
        settings.mouseResize == .layout
    }

    var body: some View {
        HStack(spacing: 4) {
            pane(flex: 6)
            divider
            pane(flex: 4)
        }
    }

    private func pane(flex: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(
                palette?.ghostFill
                    ?? Color.secondary.opacity(0.08)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(
                        palette?.frame
                            ?? Color.secondary.opacity(0.3),
                        lineWidth: 1.5
                    )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(0)
            .frame(minWidth: 0)
            .frame(idealWidth: flex * 20)
    }

    private var divider: some View {
        let accent =
            resizes
            ? palette?.accent ?? SettingsTheme.accent
            : palette?.ghostStroke
                ?? Color.secondary.opacity(0.4)
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
