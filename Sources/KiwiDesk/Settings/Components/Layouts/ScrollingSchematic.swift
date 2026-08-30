import KiwiDeskCore
import SwiftUI

/// Scrolling layout schematic showing continuous window row and focus anchor
/// (#125, #239, #753).
struct ScrollingSchematic: View {
    let orientation: ScrollingParams.Orientation
    let anchor: ScrollingParams.Anchor
    let slotSize: ScrollSize
    let placement: SpawnPlacement
    /// Windows in row including incoming window.
    var windows = LayoutSchematic.defaultWindowCount
    var scale: SchematicScale = .tile

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    /// Restage animation damping gated by Reduce Motion (#1069).
    private var damping: Animation? {
        reduceMotion ? nil : LayoutSchematic.damping
    }

    /// Monitor share of canvas along scroll axis (`LayoutSchematicScaleTests`,
    /// #753).
    var screenFraction: CGFloat { scale == .panel ? 0.6 : 1 }

    /// Whether canvas leaves margins beside monitor for overflow ghosts.
    var hasMargin: Bool { screenFraction < 1 }

    /// Whether to stroke explicit monitor outline
    /// (`LayoutSchematicScaleTests`).
    var drawsMonitorOutline: Bool { hasMargin }

    private var horizontal: Bool { orientation == .horizontal }

    /// Row slot bounds and incoming window offset relative to focus (#702,
    /// `LayoutSchematicCountTests`, `LayoutSchematicScrollingTests`).
    var row: (slots: ClosedRange<Int>, incoming: Int) {
        let total = max(2, windows)
        let established = total - 1
        let placed = SchematicPlacement.splice(
            placement,
            count: established,
            focus: (established - 1) / 2
        )
        return (
            (0 - placed.focus)...(total - 1 - placed.focus),
            placed.incoming - placed.focus
        )
    }

    /// Slot thickness as fraction of screen axis.
    private var thickness: CGFloat {
        switch slotSize {
        case .auto:
            return horizontal ? 0.46 : 0.5
        case .points(let points):
            return SchematicMath.slotFraction(points: points)
        case .fraction(let fraction):
            return CGFloat(min(max(fraction, 0.12), 0.92))
        }
    }

    var body: some View {
        SchematicCanvas(
            width: scale.width,
            height: scale.height,
            caption: caption,
            axLabel: axLabel,
            showsCaption: scale.showsCaption
        ) {
            GeometryReader { geo in
                strip(geo.size)
            }
            .animation(damping, value: anchor)
            .animation(damping, value: orientation)
            .animation(damping, value: slotSize)
            .animation(damping, value: placement)
            .animation(damping, value: windows)
        }
    }

    /// Layout metrics for continuous scrolling strip.
    struct Metrics {
        var slot: CGFloat
        var step: CGFloat
        var screenStart: CGFloat
        var screenLen: CGFloat
        var focusCenter: CGFloat
        var newIdx: Int
        var low: Int
        var high: Int
    }

    func metrics(along: CGFloat) -> Metrics {
        let screenLen = along * screenFraction
        let screenStart = (along - screenLen) / 2
        let slot = max(14, screenLen * thickness)
        let gap: CGFloat = 3
        let step = slot + gap
        let placed = row
        let low = placed.slots.lowerBound
        let high = placed.slots.upperBound
        let newIdx = placed.incoming
        let count = high - low + 1
        let rowLength = CGFloat(count) * step - gap
        let focusedPos = CGFloat(-low) * step
        let viewport = ScrollingLayout.offset(
            anchor: anchor == .follow ? .center : anchor,
            previous: nil,
            focus: nil,
            along: screenLen,
            size: slot,
            rowLength: rowLength,
            focusedPos: focusedPos
        )
        let focusCenter =
            screenStart + viewport + focusedPos + slot / 2
        return Metrics(
            slot: slot,
            step: step,
            screenStart: screenStart,
            screenLen: screenLen,
            focusCenter: focusCenter,
            newIdx: newIdx,
            low: low,
            high: high
        )
    }

    @ViewBuilder
    private func strip(_ size: CGSize) -> some View {
        let along = horizontal ? size.width : size.height
        let cross = horizontal ? size.height : size.width
        let m = metrics(along: along)
        ZStack {
            ForEach(m.low...m.high, id: \.self) { i in
                slotView(i, m, along: along)
                    .frame(
                        width: horizontal ? m.slot : cross,
                        height: horizontal ? cross : m.slot
                    )
                    .position(
                        x: horizontal ? center(i, m) : cross / 2,
                        y: horizontal ? cross / 2 : center(i, m)
                    )
            }
            if drawsMonitorOutline {
                outline(m, cross: cross)
            }
        }
    }

    /// Along-axis centre of window `i` (index 0 is the focus).
    func center(_ i: Int, _ m: Metrics) -> CGFloat {
        m.focusCenter + CGFloat(i) * m.step
    }

    @ViewBuilder
    private func slotView(
        _ i: Int,
        _ m: Metrics,
        along: CGFloat
    ) -> some View {
        if !onCanvas(i, m, along: along) {
            EmptyView()
        } else if i == m.newIdx {
            SchematicNewWindow(badgeAlignment: badgeAlignment(i))
        } else if onScreen(i, m) {
            SchematicTile(active: i == 0)
        } else {
            SchematicGhostOverflow()
        }
    }

    private func badgeAlignment(_ i: Int) -> Alignment {
        if horizontal {
            return i > 0 ? .bottomLeading : .bottomTrailing
        }
        return i > 0 ? .topTrailing : .bottomTrailing
    }

    /// Whether window `i` overlaps the screen frame.
    private func onScreen(_ i: Int, _ m: Metrics) -> Bool {
        let c = center(i, m)
        return c + m.slot / 2 > m.screenStart
            && c - m.slot / 2 < m.screenStart + m.screenLen
    }

    /// Whether window `i` reaches canvas (`LayoutSchematicCaptionTests`,
    /// #753).
    func onCanvas(_ i: Int, _ m: Metrics, along: CGFloat) -> Bool {
        let c = center(i, m)
        return c + m.slot / 2 > 0 && c - m.slot / 2 < along
    }

    private func outline(_ m: Metrics, cross: CGFloat) -> some View {
        let center = m.screenStart + m.screenLen / 2
        return RoundedRectangle(cornerRadius: 4)
            .strokeBorder(
                SettingsTheme.ink2.opacity(0.85),
                lineWidth: 2
            )
            .frame(
                width: horizontal ? m.screenLen : cross,
                height: horizontal ? cross : m.screenLen
            )
            .position(
                x: horizontal ? center : cross / 2,
                y: horizontal ? cross / 2 : center
            )
    }
}
