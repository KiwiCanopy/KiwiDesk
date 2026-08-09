import KiwiDeskCore
import SwiftUI

/// The Scrolling schematic (#125, #239, #753): a **screen
/// outline** (the monitor) with one continuous row of windows
/// moving *through* it. The focus anchor sets where the **focused
/// window** rests inside the frame, applied on every focus:
///
/// - **center** → focus centred, a neighbour peeking in on each
///   side (two partials).
/// - **start** → focus flush against the leading edge (left when
///   horizontal, top when vertical), one neighbour peeking on the
///   trailing side.
/// - **end** → mirror image (right / bottom).
/// - **follow** → the neutral resting frame, drawn centred. It
///   fixes the focus nowhere: it pans the minimum needed to
///   reveal it, so where the row rests depends on the direction
///   the reader last moved — history a preview does not have.
///   Its frame is therefore pixel-identical to `center`'s, and
///   the caption is the only place the two can be told apart —
///   which is why the words switch on the anchor
///   (`ScrollingSchematic+Caption`).
///
/// The focused window is always fully visible; neighbours are cut
/// by the frame so their partial width shows the real slot size
/// (a wide slot shows slivers, a thin slot shows many). The dense
/// `+` marks where the current placement opens the next window,
/// at the counts where the row puts it on the canvas at all.
struct ScrollingSchematic: View {
    let orientation: ScrollingParams.Orientation
    let anchor: ScrollingParams.Anchor
    let slotSize: ScrollSize
    let placement: SpawnPlacement
    /// Windows in the row, the incoming one included. The row is
    /// **finite** since turn 10: a Scrolling space with three
    /// windows and a narrow slot has nothing off either edge, and
    /// an endlessly-continuing row said otherwise at every count.
    var windows = LayoutSchematic.defaultWindowCount
    var scale: SchematicScale = .tile

    /// The monitor's share of the canvas along the scroll axis.
    ///
    /// At `.panel` it is a slice of a wider canvas, so the
    /// off-monitor ghosts have room to be read and carry a real
    /// fact — the row continues past both edges. At `.tile` there
    /// is no such room, and reserving it drew the screen outline
    /// at half the scale of every sibling's (#753), so the
    /// thumbnail spends its whole canvas on the monitor.
    ///
    /// Internal so `LayoutSchematicScaleTests` can assert both
    /// halves; a scale-blind constant is exactly the regression.
    var screenFraction: CGFloat { scale == .panel ? 0.6 : 1 }

    /// Whether the monitor draws an outline of its own. Only when
    /// it is a *slice* of the canvas: where the two coincide the
    /// canvas border already is the monitor, and a second rounded
    /// stroke on the same bounds double-strikes it.
    ///
    /// `LayoutSchematicScaleTests` needles the use site as well as
    /// the value — a view drawing off a resolved answer is
    /// deletable at its branch with every property assertion above
    /// it still green.
    var drawsMonitorOutline: Bool { screenFraction < 1 }

    private var horizontal: Bool { orientation == .horizontal }

    /// The row's slots and the incoming window's slot among
    /// them, all read relative to the focused window at 0. The
    /// row is finite, so the focus sits mid-array and the row
    /// extends both ways as far as the count allows; first /
    /// last then land the `+` on the row's real ends rather than
    /// on whichever tile the canvas happened to crop.
    ///
    /// Where the `+` lands is the engine's answer, asked through
    /// `SchematicPlacement` rather than reproduced here (#702).
    /// The splice can push the focus a slot along, and since
    /// this schematic pins the focus to 0 it is the *row* that
    /// shifts instead — which is why the bounds come from the
    /// same splice and not from a separate midpoint.
    ///
    /// Internal rather than private so `LayoutSchematicCountTests`
    /// and `LayoutSchematicScrollingTests` can assert the
    /// arithmetic. A source scan for the count as an input is
    /// satisfiable by a schematic that takes it and draws a
    /// constant — guard-prover demonstrated exactly that — so
    /// the guard has to read the derived value, and the derived
    /// value has to be reachable.
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

    /// The slot's real width as a fraction of the screen axis — a
    /// wide slot fills most of the frame (one window plus slivers),
    /// a thin one lets several show.
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
            .animation(LayoutSchematic.damping, value: anchor)
            .animation(LayoutSchematic.damping, value: orientation)
            .animation(LayoutSchematic.damping, value: slotSize)
            .animation(LayoutSchematic.damping, value: placement)
            .animation(LayoutSchematic.damping, value: windows)
        }
    }

    /// Strip geometry derived once. The focused window is index 0,
    /// centred at `focusCenter`; window `i` sits `i` steps away.
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
        let step = slot + 3
        // Anchor the FOCUSED window in the frame: centred, or flush
        // against the leading/trailing edge (its far side then
        // shows the peeking neighbour).
        let focusCenter: CGFloat
        switch anchor {
        // `.follow` rests centred — it pins the focus nowhere, so
        // the neutral frame (both neighbours in view) is the one
        // resting position that claims nothing the settings do
        // not decide. The pan is the caption's to state (#753).
        case .center, .follow:
            focusCenter = screenStart + screenLen / 2
        case .start: focusCenter = screenStart + slot / 2
        case .end:
            focusCenter = screenStart + screenLen - slot / 2
        }
        let placed = row
        let low = placed.slots.lowerBound
        let high = placed.slots.upperBound
        let newIdx = placed.incoming
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

    /// A slot the canvas cannot reach draws **nothing**, rather
    /// than being left to the clip — which does not crop where a
    /// reader would assume, as `SchematicCanvas.screen` explains.
    /// A tile just past the canvas therefore still bled a few
    /// points of itself in, most visibly as a grey ghost at a
    /// thumbnail's edge, where the monitor IS the canvas and every
    /// off-monitor slot is one of these.
    ///
    /// Otherwise: the new window is the dense `+` tile; a
    /// window overlapping the monitor at all is on screen (accent,
    /// the focus heavier), even partially; one entirely past a
    /// monitor edge but still on the canvas is an off-monitor
    /// ghost (gray), which only the panel's margin has room for.
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

    /// The "+" badge sits on the side of the new-window tile facing
    /// the screen centre. For a first/last window — which straddles
    /// the canvas edge — that keeps the badge in the visible half:
    /// a trailing (last) tile is cropped on its trailing side, so
    /// the badge moves to the leading corner, and vice versa.
    private func badgeAlignment(_ i: Int) -> Alignment {
        if horizontal {
            return i > 0 ? .bottomLeading : .bottomTrailing
        }
        return i > 0 ? .topTrailing : .bottomTrailing
    }

    /// Whether window `i` overlaps the screen frame at all.
    private func onScreen(_ i: Int, _ m: Metrics) -> Bool {
        let c = center(i, m)
        return c + m.slot / 2 > m.screenStart
            && c - m.slot / 2 < m.screenStart + m.screenLen
    }

    /// Whether window `i` reaches the **canvas** at all. The row is
    /// finite but several canvases wide at most counts, so this is
    /// what decides how much of it is ever seen. Internal so
    /// `LayoutSchematicCaptionTests` can hold the caption's `+`
    /// clause to the drawing rather than to a second model of it
    /// (#753).
    func onCanvas(_ i: Int, _ m: Metrics, along: CGFloat) -> Bool {
        let c = center(i, m)
        return c + m.slot / 2 > 0 && c - m.slot / 2 < along
    }

    private func outline(_ m: Metrics, cross: CGFloat) -> some View {
        let center = m.screenStart + m.screenLen / 2
        return RoundedRectangle(cornerRadius: 4)
            .strokeBorder(
                Color.secondary.opacity(0.85),
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
