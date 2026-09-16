import KiwiDeskCore
import SwiftUI

/// Scrolling layout schematic showing continuous window row and focus anchor
/// (#125, #239, #753).
struct ScrollingSchematic: View {
    let orientation: ScrollingParams.Orientation
    let anchor: ScrollingParams.Anchor
    let slotSize: ScrollSize
    let placement: SpawnPlacement
    /// "If one window, fill the screen" (#1389).
    var fillWhenAlone = true
    /// Windows in row including incoming window.
    var windows = LayoutSchematic.defaultWindowCount
    var scale: SchematicScale = .tile

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    /// The along-axis length the strip last laid out at — what the
    /// words are judged on, since the pane's width is the host's
    /// (`LayoutSchematicCenterCaptionTests`).
    @State private var drawnAlong: CGFloat?

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

    /// The lone-window frame (#1389): one slot, no incoming
    /// window, and no insertion mark to point at.
    var lone: Bool { windows == 1 }

    /// Row slot bounds and incoming window offset relative to focus (#702,
    /// `LayoutSchematicCountTests`, `LayoutSchematicScrollingTests`).
    var row: (slots: ClosedRange<Int>, incoming: Int) {
        guard !lone else { return (0...0, 0) }
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

    /// The canvas's inner gap between slots.
    static let slotGap: CGFloat = 3

    /// The slot's span on a `screenLen` screen: the whole screen
    /// for a lone window that fills (#1389,
    /// `LayoutSchematicAloneTests`); a share is the ENGINE's
    /// pitch share (`ScrollSize.resolved`, #1382), so 50% draws
    /// two windows side by side, gaps included; auto and points
    /// are stylised for the mini canvas.
    func slot(screenLen: CGFloat) -> CGFloat {
        guard !(lone && fillWhenAlone) else { return screenLen }
        switch slotSize {
        case .auto:
            return screenLen * (horizontal ? 0.46 : 0.5)
        case .points(let points):
            return screenLen * SchematicMath.slotFraction(points: points)
        case .fraction(let fraction):
            return ScrollSize.fraction(min(max(fraction, 0.12), 0.92))
                .resolved(
                    along: screenLen,
                    gap: Self.slotGap,
                    horizontal: horizontal
                )
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
            .animation(damping, value: fillWhenAlone)
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
        let slot = max(14, slot(screenLen: screenLen))
        let gap = Self.slotGap
        let step = slot + gap
        let placed = row
        let low = placed.slots.lowerBound
        let high = placed.slots.upperBound
        let newIdx = placed.incoming
        // Where the row rests is the ENGINE's answer (#776). A
        // static preview has no pan history, so `follow` is asked
        // from a centred one — the engine's own `.center` rest
        // (#753, #1388).
        let count = high - low + 1
        let rowLength = CGFloat(count) * step - gap
        let focusedPos = CGFloat(-low) * step
        let resting = ScrollingLayout.offset(
            anchor: anchor.keepsRowOnScreen ? .center : anchor,
            previous: nil,
            focus: nil,
            along: screenLen,
            size: slot,
            rowLength: rowLength,
            focusedPos: focusedPos
        )
        let viewport =
            anchor.keepsRowOnScreen
            ? ScrollingLayout.offset(
                anchor: .follow,
                previous: ScrollRest(offset: resting),
                focus: nil,
                along: screenLen,
                size: slot,
                rowLength: rowLength,
                focusedPos: focusedPos
            )
            : resting
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
            Color.clear
                .onAppear { drawnAlong = along }
                .onChange(of: along) { _, now in drawnAlong = now }
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
        } else if i == m.newIdx, !lone {
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
        overlap(i, m) > 0
    }

    /// How much of window `i` lies inside the screen frame.
    private func overlap(_ i: Int, _ m: Metrics) -> CGFloat {
        let c = center(i, m)
        let lead = max(c - m.slot / 2, m.screenStart)
        let trail = min(c + m.slot / 2, m.screenStart + m.screenLen)
        return max(0, trail - lead)
    }

    /// Under half a point — the drawing's own quantum — is
    /// neither a drawn cut nor a drawn sliver, on either edge.
    static let cutQuantum: CGFloat = 0.5

    /// Whether the frame drawn at `along` has a window the screen
    /// edge cuts: one on canvas showing more than the quantum and
    /// less than its whole.
    func cutsWindow(along: CGFloat) -> Bool {
        let m = metrics(along: along)
        return (m.low...m.high).contains { i in
            let shown = overlap(i, m)
            return onCanvas(i, m, along: along)
                && shown > Self.cutQuantum
                && shown < m.slot - Self.cutQuantum
        }
    }

    /// The Center caption's clause at `along`.
    func drawsCutWindows(along: CGFloat) -> Bool {
        !lone && cutsWindow(along: along)
    }

    /// The clause as the view speaks it: judged on the length the
    /// strip DREW, spoken at `.tile` too — never on a length no
    /// scale draws; before the first layout pass, and in a test,
    /// on the scale's own fixed length.
    var drawsCutWindows: Bool { drawsCutWindows(along: judgedAlong) }

    /// The along-axis length the words are judged at.
    var judgedAlong: CGFloat { drawnAlong ?? fixedAlong }

    /// The scale's own along-axis length where it has one — the
    /// canvas less the inset band on both ends — the panel's
    /// height standing in for its pane width until it is drawn.
    var fixedAlong: CGFloat {
        let canvas =
            horizontal
            ? scale.width ?? SchematicScale.panel.height
            : scale.height
        return canvas - 2 * LayoutSchematic.inset
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
