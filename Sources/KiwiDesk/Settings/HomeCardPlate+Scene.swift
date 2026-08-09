import KiwiDeskCore
import SwiftUI

/// The scene tiles of the Home card plates (#786): Gaps &
/// Borders, Bars and Monitors. Split from `HomeCardPlate.swift`
/// at the file-size target; the container, palette and dispatch
/// stay there.

/// Two panes whose spacing IS the answer: the gap between them
/// reads the inner gap, the insets to the plate edge the outer
/// gaps — each through `GapPreviewScale.mini`, the same maths
/// the Gaps editor teaches with — and the focused pane's stroke
/// reads the border width through `FocusBorderPreview`'s 1–20 →
/// 1–7 remap, in the border's own colour. Deliberately not a
/// layout preview, like the diagram it echoes.
struct HomeCardGapsTile: View {
    let settings: TilingSettings
    @Environment(\.schematicPalette) private var palette

    var body: some View {
        let outer = settings.gapsGlobal.outer
        let inner = settings.gapsGlobal.inner
        HStack(spacing: mini(inner.horizontal)) {
            pane(focused: true)
            pane(focused: false)
        }
        .padding(.top, mini(outer.top))
        .padding(.bottom, mini(outer.bottom))
        .padding(.leading, mini(outer.left))
        .padding(.trailing, mini(outer.right))
    }

    private func mini(_ real: CGFloat) -> CGFloat {
        GapPreviewScale.mini(real)
    }

    @ViewBuilder
    private func pane(focused: Bool) -> some View {
        let border = settings.borderStyle
        let ringed =
            border.enabled
            && (focused || border.unfocusedEnabled)
        RoundedRectangle(cornerRadius: 6)
            .fill(
                focused
                    ? palette?.fill ?? LayoutSchematic.fill
                    : palette?.ghostFill
                        ?? Color.secondary.opacity(0.15)
            )
            .overlay {
                if ringed {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            Color(
                                kiwiHex: focused
                                    ? border.focusedColor
                                    : border.unfocusedColor
                            ),
                            lineWidth: strokeWidth
                        )
                }
            }
    }

    /// `FocusBorderPreview`'s remap, so the two readouts of one
    /// width can never disagree about scale.
    private var strokeWidth: CGFloat {
        let t = min(
            max((settings.borderStyle.clampedWidth - 1) / 19, 0),
            1
        )
        return 1 + t * 6
    }
}

/// The Bars picture: each enabled bar as a plate on its own
/// edge in its own fill, the desktop well between them. The
/// edge-most bar on a shared edge is the Space Bar, matching
/// `SpaceBarPreviewStrip`'s coexistence order.
struct HomeCardBarsTile: View {
    let settings: TilingSettings
    @Environment(\.schematicPalette) private var palette

    var body: some View {
        HStack(spacing: 3) {
            columnBars(.left)
            VStack(spacing: 3) {
                rowBars(.top)
                well
                rowBars(.bottom)
            }
            columnBars(.right)
        }
    }

    private var well: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(
                palette?.ghostFill
                    ?? Color.secondary.opacity(0.08)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(
                        palette?.frame
                            ?? Color.secondary.opacity(0.3)
                    )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The bars on a horizontal edge, edge-most first for
    /// `.top` and window-most first for `.bottom`, so both hug
    /// the screen edge.
    @ViewBuilder
    private func rowBars(_ edge: AppBarEdge) -> some View {
        if edge == .top {
            spaceStrip(on: edge)
            appStrip(on: edge)
        } else {
            appStrip(on: edge)
            spaceStrip(on: edge)
        }
    }

    @ViewBuilder
    private func columnBars(_ edge: AppBarEdge) -> some View {
        if edge == .left {
            spaceStrip(on: edge, vertical: true)
            appStrip(on: edge, vertical: true)
        } else {
            appStrip(on: edge, vertical: true)
            spaceStrip(on: edge, vertical: true)
        }
    }

    @ViewBuilder
    private func spaceStrip(
        on edge: AppBarEdge,
        vertical: Bool = false
    ) -> some View {
        let style = settings.spaceBarStyle
        if style.enabled, style.edge == edge {
            barPlate(
                fill: style.fillColor,
                items: [
                    (style.activeItemColor, CGFloat(12)),
                    (style.itemColor, 12),
                    (style.itemColor, 12),
                ],
                vertical: vertical
            )
        }
    }

    @ViewBuilder
    private func appStrip(
        on edge: AppBarEdge,
        vertical: Bool = false
    ) -> some View {
        let style = settings.appBarStyle
        if style.edge == edge {
            barPlate(
                fill: style.fillColor,
                items: [
                    (style.activeItemColor, CGFloat(20)),
                    (style.itemColor, 20),
                ],
                vertical: vertical
            )
        }
    }

    private func barPlate(
        fill: String,
        items: [(String, CGFloat)],
        vertical: Bool
    ) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Color(kiwiHex: fill))
            .frame(
                width: vertical ? 16 : nil,
                height: vertical ? nil : 16
            )
            .overlay(
                stack(vertical: vertical) {
                    ForEach(
                        Array(items.enumerated()),
                        id: \.offset
                    ) { _, item in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(kiwiHex: item.0))
                            .frame(
                                width: vertical ? 9 : item.1,
                                height: vertical ? item.1 : 9
                            )
                    }
                }
                .padding(vertical ? .vertical : .horizontal, 5)
            )
    }

    @ViewBuilder
    private func stack(
        vertical: Bool,
        @ViewBuilder content: () -> some View
    ) -> some View {
        if vertical {
            VStack(spacing: 4) {
                content()
                Spacer(minLength: 0)
            }
        } else {
            HStack(spacing: 4) {
                content()
                Spacer(minLength: 0)
            }
        }
    }
}

/// The Monitors picture, small: the real display set through
/// the one arrangement maths (`MonitorArrangement.layout`,
/// chip-less), each display on a stand derived from the #758
/// share tokens — shares only; the point clamps belong to the
/// area picture's card sizes — with the main display in the
/// palette accent carrying two window pips.
struct HomeCardMonitorsTile: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.schematicPalette) private var palette

    /// The mini stand band under each display card.
    private static let standBand: CGFloat = 8

    var body: some View {
        let mainID = PositionalDisplays.liveMainID
        GeometryReader { proxy in
            let layout = MonitorArrangement.layout(
                displays: model.displays,
                mainID: mainID,
                canvas: proxy.size,
                hostsChips: false
            )
            ForEach(layout.displays) { drawn in
                display(
                    drawn,
                    main: drawn.display.id == mainID
                )
            }
        }
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
                    if main {
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
