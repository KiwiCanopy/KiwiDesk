import KiwiDeskCore
import SwiftUI

/// The Track schematic (#125): tracks running along the staged
/// `axis` (vertical = columns side-by-side, horizontal = rows),
/// with a far-edge **overflow track** that piles its windows — the
/// Stack cascade, always vertical (#192). The focused track carries
/// two windows in a heavier stroke (tracks hold multiple windows),
/// and the new window reads as either a **whole `+` track** (new
/// windows open their own) or a **nested `+`** inside the focused
/// track (they join it), placed where `newWindowPosition` opens it.
///
/// A limit shows that many normal tracks; auto-tracks shows three
/// (the count is a magnitude, bounded by the minimum window size —
/// stated in the editor caption, not counted out here).
struct TrackSchematic: View {
    let axis: TrackParams.Axis
    let overflowStyle: StackParams.OverflowStyle
    let newWindow: TrackParams.NewWindowTrack
    let placement: SpawnPlacement
    let count: Int
    let autoTracks: Bool

    private var vertical: Bool { axis == .vertical }
    private var trackCount: Int {
        autoTracks ? 3 : min(max(count, 1), 4)
    }
    private var focusIdx: Int { trackCount / 2 }

    private struct TrackSpec {
        var focused = false
        var isNew = false
        var nestedNew = false
    }

    var body: some View {
        SchematicCanvas(caption: caption, axLabel: axLabel) {
            strip
                .animation(LayoutSchematic.damping, value: axis)
                .animation(
                    LayoutSchematic.damping,
                    value: overflowStyle
                )
                .animation(LayoutSchematic.damping, value: newWindow)
                .animation(LayoutSchematic.damping, value: placement)
                .animation(LayoutSchematic.damping, value: count)
                .animation(LayoutSchematic.damping, value: autoTracks)
        }
    }

    /// Normal tracks with the new *track* spliced in (for
    /// `own_track`) at its placement slot; `focused_track` instead
    /// nests the new window inside the focused track.
    private var specs: [TrackSpec] {
        var s = (0..<trackCount).map {
            TrackSpec(focused: $0 == focusIdx)
        }
        switch newWindow {
        case .focusedTrack:
            s[focusIdx].nestedNew = true
        case .ownTrack:
            s.insert(TrackSpec(isNew: true), at: newTrackIndex)
        }
        return s
    }

    private var newTrackIndex: Int {
        switch placement {
        case .first: return 0
        case .last: return trackCount
        case .beforeFocused: return focusIdx
        case .afterFocused: return focusIdx + 1
        }
    }

    @ViewBuilder
    private var strip: some View {
        if vertical {
            HStack(spacing: 3) { trackViews }
        } else {
            VStack(spacing: 3) { trackViews }
        }
    }

    @ViewBuilder
    private var trackViews: some View {
        ForEach(specs.indices, id: \.self) { i in
            trackView(specs[i])
        }
        overflowTrack
    }

    private enum TrackWindow { case plain, focus, new }

    @ViewBuilder
    private func trackView(_ spec: TrackSpec) -> some View {
        if spec.isNew {
            SchematicNewWindow()
        } else if spec.focused {
            focusedTrack(nested: spec.nestedNew)
        } else {
            SchematicTile()
        }
    }

    /// The focused track holds several windows so multi-window
    /// tracks read. The focus is pinned to the middle slot; when new
    /// windows join here, the `+` lands at its placement slot around
    /// it (first / last on the ends, before / after right beside
    /// it) — the focus stays put so the placement reads relative to
    /// a fixed reference, not a drifting one.
    private func focusedTrack(nested: Bool) -> some View {
        // 4 windows normally (focus = 3rd); a 5th slot appears for
        // the joining window, keeping the focus centred.
        let slots = nested ? 5 : 4
        let focus = 2
        let plus = nested ? focusedPlusIndex() : -1
        return axisStack {
            ForEach(0..<slots, id: \.self) { i in
                trackWindow(
                    i == plus ? .new : i == focus ? .focus : .plain
                )
            }
        }
    }

    /// Slot for the joining window, with the focus fixed at index 2.
    private func focusedPlusIndex() -> Int {
        switch placement {
        case .first: return 0
        case .last: return 4
        case .beforeFocused: return 1
        case .afterFocused: return 3
        }
    }

    @ViewBuilder
    private func trackWindow(_ window: TrackWindow) -> some View {
        switch window {
        case .plain: SchematicTile()
        case .focus: SchematicTile(active: true)
        case .new: SchematicNewWindow()
        }
    }

    /// Windows stack along the track's own axis: down a column when
    /// tracks are vertical, across a row when horizontal.
    @ViewBuilder
    private func axisStack<C: View>(
        @ViewBuilder _ content: () -> C
    ) -> some View {
        if vertical {
            VStack(spacing: 2) { content() }
        } else {
            HStack(spacing: 2) { content() }
        }
    }

    /// The far-edge overflow track: an always-vertical title-bar
    /// pile. `cascade_all` piles every window; `cascade_overflow`
    /// keeps the first tiled and piles the rest.
    private var overflowTrack: some View {
        GeometryReader { geo in
            let slots = overflowSlots(geo.size)
            ZStack(alignment: .topLeading) {
                ForEach(slots.indices, id: \.self) { i in
                    overflowTile
                        .frame(
                            width: slots[i].width,
                            height: slots[i].height
                        )
                        .position(x: slots[i].midX, y: slots[i].midY)
                }
            }
        }
    }

    /// Six windows piling down the overflow track (always vertical),
    /// the same shape as the Stack cascade: `cascade_all` piles all
    /// six; `cascade_overflow` tiles the first three and piles the
    /// last three.
    private func overflowSlots(_ size: CGSize) -> [CGRect] {
        let n = 6
        let w = size.width
        let h = size.height
        let off: CGFloat = 6
        if overflowStyle == .cascadeAll {
            let tileH = max(6, h - off * CGFloat(n - 1))
            return (0..<n).map {
                CGRect(
                    x: 0,
                    y: CGFloat($0) * off,
                    width: w,
                    height: tileH
                )
            }
        }
        let tiled = 3
        let piled = n - tiled
        let g: CGFloat = 3
        let rowH = max(
            8,
            (h - g * CGFloat(tiled) - off * CGFloat(piled - 1))
                / CGFloat(tiled + 1)
        )
        var rects: [CGRect] = []
        for i in 0..<tiled {
            rects.append(
                CGRect(
                    x: 0,
                    y: CGFloat(i) * (rowH + g),
                    width: w,
                    height: rowH
                )
            )
        }
        let top = CGFloat(tiled) * (rowH + g)
        for k in 0..<piled {
            rects.append(
                CGRect(
                    x: 0,
                    y: top + CGFloat(k) * off,
                    width: w,
                    height: rowH
                )
            )
        }
        return rects
    }

    /// An opaque cascade tile (own solid base, so overlapping never
    /// sums the accent alpha) — same look as the Stack pile.
    private var overflowTile: some View {
        let corner = LayoutSchematic.corner
        return ZStack {
            RoundedRectangle(cornerRadius: corner)
                .fill(Color(nsColor: .textBackgroundColor))
            RoundedRectangle(cornerRadius: corner)
                .fill(LayoutSchematic.fill)
            RoundedRectangle(cornerRadius: corner)
                .strokeBorder(LayoutSchematic.stroke, lineWidth: 1)
        }
    }

    private var caption: String {
        switch newWindow {
        case .ownTrack:
            return L(
                "layout.schematic.track.caption_own",
                "New windows open their own track; the far track "
                    + "piles the overflow."
            )
        case .focusedTrack:
            return L(
                "layout.schematic.track.caption_focused",
                "New windows join the focused track; the far track "
                    + "piles the overflow."
            )
        }
    }

    private var axLabel: String {
        L(
            "layout.schematic.track.ax",
            "Track preview: tracks along one axis, the far one "
                + "piling overflow; the plus is the next window."
        )
    }
}
