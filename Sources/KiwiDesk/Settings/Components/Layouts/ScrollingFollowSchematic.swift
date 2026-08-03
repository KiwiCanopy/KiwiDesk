import KiwiDeskCore
import SwiftUI

/// The `follow` anchor's two-frame schematic (#239). Unlike
/// center/start/end — each a resting position expressible in one
/// still frame — `follow` is a *transition*: hold the viewport,
/// pan the minimum to reveal the newly focused slot. A single
/// frame can't denote motion, so it earns a `SchematicPair` (the
/// same bar Grid's `.dynamic` and BSP clear — "a fact
/// inexpressible in one frame", see design-decisions).
///
/// - **Frame 1** — the focus (thick accent stroke) sits mid-row,
///   neighbours on both sides.
/// - **Frame 2** — focus steps one slot over; the viewport pans
///   just far enough to bring it fully into view, so the slot we
///   came from **stays visible on the leading side** (the "keeps
///   the side you came from open" fact). No "+" badge — that
///   marks a *spawn*, a different idea (vocabulary collision);
///   the moved focus is carried by the active/non-active tile
///   stroke alone.
struct ScrollingFollowPair: View {
    let orientation: ScrollingParams.Orientation
    let slotSize: ScrollSize
    /// Windows in the row. The pair's subject is the *pan*, not
    /// the fill, so the count changes only how long the row is —
    /// but it has to change that, or a three-window space is
    /// shown panning through six slots that do not exist.
    var windows = LayoutSchematic.defaultWindowCount
    var scale: SchematicScale = .tile

    private var horizontal: Bool { orientation == .horizontal }

    /// The finite row's slot indices, focus at 0. Frame 2 steps
    /// the focus to index 1, which the floor of two windows
    /// always provides.
    var slots: ClosedRange<Int> {
        let count = max(2, windows)
        let focusPos = (count - 1) / 2
        return -focusPos...(count - 1 - focusPos)
    }

    /// Two panes share the width, so a panel-wide pair takes half
    /// each — `nil` from `SchematicScale` means "fill", and the
    /// `HStack` does the halving. A thumbnail keeps the fixed
    /// per-orientation frames, which are already tile-sized.
    private var paneWidth: CGFloat? {
        scale == .panel ? nil : (horizontal ? 128 : 92)
    }

    private var paneHeight: CGFloat {
        scale == .panel
            ? scale.height : (horizontal ? 76 : 104)
    }

    /// Slot length as a fraction of the along axis. Kept on the
    /// thin side so both neighbours stay visible — the pan, not
    /// the slot width, is the point here.
    private var slotFraction: CGFloat {
        switch slotSize {
        case .auto:
            return 0.4
        case .points(let points):
            return SchematicMath.slotFraction(points: points)
        case .fraction(let fraction):
            return CGFloat(min(max(fraction, 0.2), 0.55))
        }
    }

    var body: some View {
        SchematicPair(
            frameWidth: paneWidth,
            frameHeight: paneHeight,
            firstCaption: L(
                "layout.schematic.scrolling.follow_a",
                "Focus here"
            ),
            secondCaption: L(
                "layout.schematic.scrolling.follow_b",
                "When focus steps to the next window"
            ),
            caption: caption,
            axLabel: axLabel,
            showsCaption: scale.showsCaption
        ) {
            frame(stepped: false)
        } second: {
            frame(stepped: true)
        }
    }

    private func frame(stepped: Bool) -> some View {
        GeometryReader { geo in
            let along = horizontal ? geo.size.width : geo.size.height
            let cross = horizontal ? geo.size.height : geo.size.width
            tiles(along: along, cross: cross, stepped: stepped)
        }
        .animation(LayoutSchematic.damping, value: orientation)
        .animation(LayoutSchematic.damping, value: slotSize)
        .animation(LayoutSchematic.damping, value: windows)
    }

    /// The row of slots for one frame. Frame 1 rests the focus
    /// (index 0) centred; frame 2 focuses index 1 and pans the
    /// viewport the minimum needed to reveal it, leaving index 0
    /// visible on the leading side.
    private func tiles(
        along: CGFloat,
        cross: CGFloat,
        stepped: Bool
    ) -> some View {
        let slot = along * slotFraction
        let stride = slot + 4
        let center = along / 2
        let focus = stepped ? 1 : 0
        // Minimal pan: shift so the focused slot's trailing edge
        // just meets the viewport edge (0 in frame 1, focus centred).
        let pan =
            stepped
            ? max(0, center + stride + slot / 2 - along)
            : 0
        return ZStack {
            ForEach(slots, id: \.self) { i in
                let p = center + CGFloat(i) * stride - pan
                SchematicTile(active: i == focus)
                    .frame(
                        width: horizontal ? slot : cross,
                        height: horizontal ? cross : slot
                    )
                    .position(
                        x: horizontal ? p : cross / 2,
                        y: horizontal ? cross / 2 : p
                    )
            }
        }
    }

    private var caption: String {
        L(
            "layout.schematic.scrolling.follow_caption",
            "The viewport holds still and pans the minimum to "
                + "reveal the focus, keeping the side you came "
                + "from in view."
        )
    }

    private var axLabel: String {
        L(
            "layout.schematic.scrolling.follow_ax",
            "Follow preview: two frames — the focus steps one slot "
                + "over and the viewport pans just enough to reveal "
                + "it, leaving the previous window visible."
        )
    }
}
