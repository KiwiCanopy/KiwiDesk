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
/// stated in the row caption, not counted out here).
///
/// The **window count** (turn 10) is what opens and collapses
/// tracks: windows fill the normal tracks up to the limit and
/// the surplus falls into the overflow track, so dragging the
/// count past the limit is the moment the overflow track earns
/// its name — and the moment `cascade_all` and
/// `cascade_overflow` stop drawing the same picture.
struct TrackSchematic: View {
    let axis: TrackParams.Axis
    let overflowStyle: StackParams.OverflowStyle
    let newWindow: TrackParams.NewWindowTrack
    let placement: SpawnPlacement
    let limit: Int
    let autoTracks: Bool
    /// Windows on screen, the incoming one included.
    var windows = LayoutSchematic.defaultWindowCount
    var scale: SchematicScale = .tile

    private var vertical: Bool { axis == .vertical }

    /// Normal tracks, never more than there are established
    /// windows to put in them: a limit of four over two windows
    /// draws two tracks, because the fourth track does not exist
    /// until a window opens it.
    var trackCount: Int {
        let ceiling = autoTracks ? 3 : min(max(limit, 1), 4)
        return min(ceiling, max(1, established))
    }

    /// Windows already open — the count less the incoming one.
    private var established: Int { max(1, windows - 1) }

    /// Windows past the normal tracks' capacity. One window per
    /// normal track plus the focused track's own run is the
    /// capacity; anything beyond falls to the overflow track,
    /// which is empty until it does.
    var overflowWindows: Int {
        max(0, established - trackCount - focusedRun + 1)
    }

    /// Windows in the focused track. It holds several so that
    /// multi-window tracks read, but never more than the count
    /// can pay for.
    var focusedRun: Int {
        min(4, max(1, established - trackCount + 1))
    }

    var focusIdx: Int { trackCount / 2 }

    private struct TrackSpec {
        var focused = false
        var isNew = false
        var nestedNew = false
    }

    var body: some View {
        SchematicCanvas(
            width: scale.width,
            height: scale.height,
            caption: caption,
            axLabel: axLabel,
            showsCaption: scale.showsCaption
        ) {
            strip
                .animation(LayoutSchematic.damping, value: axis)
                .animation(
                    LayoutSchematic.damping,
                    value: overflowStyle
                )
                .animation(LayoutSchematic.damping, value: newWindow)
                .animation(LayoutSchematic.damping, value: placement)
                .animation(LayoutSchematic.damping, value: limit)
                .animation(LayoutSchematic.damping, value: autoTracks)
                .animation(LayoutSchematic.damping, value: windows)
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

    /// Where the new *track* slots in, asked of the engine
    /// through `SchematicPlacement` rather than reproduced here
    /// (#702). The specs array is spliced, so the focused spec
    /// travels with it and needs no correction — unlike the run
    /// inside the focused track, which draws fixed slots.
    ///
    /// Internal so `LayoutSchematicPlacementTests` can read it.
    var newTrackIndex: Int {
        SchematicPlacement.splice(
            placement,
            count: trackCount,
            focus: focusIdx
        ).incoming
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
        // No overflow track until something overflows. Drawing an
        // empty one at every count would say the far edge is
        // always reserved, which is the opposite of what the
        // track limit does.
        if overflowWindows > 0 {
            overflowTrack
        }
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
    /// tracks read, the focus starting in the middle of the run.
    /// When new windows join here the `+` lands at its placement
    /// slot around it — first / last on the ends, before / after
    /// right beside it.
    private func focusedTrack(nested: Bool) -> some View {
        // `focusedRun` windows; one more slot appears for the
        // joining window, and a landing at or before the focus
        // pushes the focus into the next slot along.
        let run = focusedRun
        let plus = nested ? focusedSlots.incoming : -1
        let focus = nested ? focusedSlots.focus : (run - 1) / 2
        return axisStack {
            ForEach(0..<(nested ? run + 1 : run), id: \.self) { i in
                trackWindow(
                    i == plus ? .new : i == focus ? .focus : .plain
                )
            }
        }
    }

    /// The joining window's slot inside the focused track, and
    /// the slot the focus ends up in once it has landed — both
    /// read off the engine's splice (#702).
    ///
    /// The focus is **not** pinned. Its own copy of the rule
    /// returned splice coordinates and the run drew in fixed
    /// slot coordinates, so `first` marked the wrong window and
    /// `before focused` resolved the `+` and the focus to one
    /// slot, where the `+` won the ternary and the run drew no
    /// focused tile at all. Only meaningful when something joins
    /// this track; an untouched run keeps its middle focus.
    var focusedSlots: (incoming: Int, focus: Int) {
        SchematicPlacement.splice(
            placement,
            count: focusedRun,
            focus: (focusedRun - 1) / 2
        )
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

    /// The overflowed windows piling down the overflow track
    /// (always vertical), the same shape as the Stack cascade:
    /// `cascade_all` piles all of them; `cascade_overflow` tiles
    /// the ones that fit and piles the rest. Only reached with at
    /// least one window to draw.
    private func overflowSlots(_ size: CGSize) -> [CGRect] {
        let n = overflowWindows
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
        let tiled = min(3, max(0, n - 1))
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
