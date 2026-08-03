import KiwiDeskCore
import SwiftUI

/// The Scrolling schematic (#125, #239): a fixed, centred
/// **screen outline** (the monitor) with one continuous row of
/// windows moving *through* it. The monitor stays in the middle of
/// the whole row — windows continue off *both* edges — and the
/// focus anchor sets where the **focused window** rests inside the
/// frame, applied on every focus:
///
/// - **center** → focus centred, a neighbour peeking in on each
///   side (two partials).
/// - **start** → focus flush against the leading edge (left when
///   horizontal, top when vertical), one neighbour peeking on the
///   trailing side.
/// - **end** → mirror image (right / bottom).
///
/// The focused window is always fully visible; neighbours are cut
/// by the frame so their partial width shows the real slot size
/// (a wide slot shows slivers, a thin slot shows many). The dense
/// `+` marks where the current placement opens the next window.
///
/// **follow** is the one anchor that can't be shown as a resting
/// position — it is a *transition* (pan the minimum to reveal the
/// focus), so it renders as a two-frame `ScrollingFollowPair`
/// instead, branched below exactly as `GridSchematic` branches on
/// `.dynamic`.
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

    /// The monitor is a fixed slice of a wider canvas, so the
    /// off-screen ghosts always have room to show.
    private let screenFraction: CGFloat = 0.5

    private var horizontal: Bool { orientation == .horizontal }

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
        if anchor == .follow {
            // A transition, not a resting position: two frames
            // (#239), like GridSchematic's `.dynamic` pair.
            ScrollingFollowPair(
                orientation: orientation,
                slotSize: slotSize,
                scale: scale
            )
        } else {
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
                .animation(
                    LayoutSchematic.damping,
                    value: orientation
                )
                .animation(LayoutSchematic.damping, value: slotSize)
                .animation(
                    LayoutSchematic.damping,
                    value: placement
                )
                .animation(LayoutSchematic.damping, value: windows)
            }
        }
    }

    /// Strip geometry derived once. The focused window is index 0,
    /// centred at `focusCenter`; window `i` sits `i` steps away.
    private struct Metrics {
        var slot: CGFloat
        var step: CGFloat
        var screenStart: CGFloat
        var screenLen: CGFloat
        var focusCenter: CGFloat
        var newIdx: Int
        var low: Int
        var high: Int
    }

    private func metrics(along: CGFloat) -> Metrics {
        let screenLen = along * screenFraction
        let screenStart = (along - screenLen) / 2
        let slot = max(14, screenLen * thickness)
        let step = slot + 3
        // Anchor the FOCUSED window in the frame: centred, or flush
        // against the leading/trailing edge (its far side then
        // shows the peeking neighbour).
        let focusCenter: CGFloat
        switch anchor {
        // `.follow` never reaches here (the body branches to the
        // two-frame pair); folded with center so the switch stays
        // exhaustive.
        case .center, .follow:
            focusCenter = screenStart + screenLen / 2
        case .start: focusCenter = screenStart + slot / 2
        case .end:
            focusCenter = screenStart + screenLen - slot / 2
        }
        // Range = the row itself, which is finite. The focus sits
        // mid-array so the row extends both ways where the count
        // allows; first / last then land the `+` on the row's real
        // ends rather than on whichever tile the canvas happened
        // to crop.
        let count = max(2, windows)
        let focusPos = (count - 1) / 2
        let low = -focusPos
        let high = count - 1 - focusPos
        let newIdx = newWindowIndex(low: low, high: high)
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
                slotView(i, m)
                    .frame(
                        width: horizontal ? m.slot : cross,
                        height: horizontal ? cross : m.slot
                    )
                    .position(
                        x: horizontal ? center(i, m) : cross / 2,
                        y: horizontal ? cross / 2 : center(i, m)
                    )
            }
            outline(m, cross: cross)
        }
    }

    /// Along-axis centre of window `i` (index 0 is the focus).
    private func center(_ i: Int, _ m: Metrics) -> CGFloat {
        m.focusCenter + CGFloat(i) * m.step
    }

    /// The new window is the dense `+` tile; a window overlapping
    /// the frame at all is on screen (accent, the focus heavier),
    /// even partially; one entirely past an edge is an off-monitor
    /// ghost (gray).
    @ViewBuilder
    private func slotView(_ i: Int, _ m: Metrics) -> some View {
        if i == m.newIdx {
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

    /// Where the new window opens, as a strip index (focus = 0):
    /// beside the focus for the relative placements, or at the very
    /// first / last end of the whole row. Clamped into the row —
    /// at two windows the focus IS an end, so "before focused" has
    /// nowhere further to go and lands on the end itself.
    private func newWindowIndex(low: Int, high: Int) -> Int {
        let raw: Int
        switch placement {
        case .first: raw = low
        case .last: raw = high
        case .beforeFocused: raw = -1
        case .afterFocused: raw = 1
        }
        return min(max(raw, low), high)
    }

    private var caption: String {
        L(
            "layout.schematic.scrolling.caption",
            "Focus rests at the anchor; the row scrolls off past "
                + "it. The + is where the next window opens."
        )
    }

    private var axLabel: String {
        L(
            "layout.schematic.scrolling.ax",
            "Scrolling preview: a row of windows framed by the "
                + "screen, continuing off both edges; the anchor "
                + "window holds focus."
        )
    }
}
