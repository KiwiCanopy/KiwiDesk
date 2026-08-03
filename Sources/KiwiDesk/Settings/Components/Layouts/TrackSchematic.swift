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

    /// The strip's tracks as it draws them: which slot holds the
    /// new track and which holds the focused one. Read off
    /// `specs` rather than recomputed, so a splice that lands
    /// somewhere other than `newTrackIndex` — or never runs —
    /// shows up in the guard (`LayoutSchematicPlacementTests`).
    var trackSlots: (incoming: Int, focus: Int) {
        let drawn = specs
        return (
            drawn.firstIndex { $0.isNew } ?? -1,
            drawn.firstIndex { $0.focused } ?? -1
        )
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
        let drawn = focusedSlots(nested: nested)
        return axisStack {
            ForEach(0..<drawn.count, id: \.self) { i in
                trackWindow(
                    i == drawn.incoming
                        ? .new
                        : i == drawn.focus ? .focus : .plain
                )
            }
        }
    }

    /// The focused track exactly as it is drawn: how many slots,
    /// which one the joining window takes and which one holds the
    /// focus. One slot appears for the joining window, and a
    /// landing at or before the focus pushes the focus along.
    ///
    /// The focus is **not** pinned, and this returns the drawn
    /// numbers rather than the placement rule's so that a guard
    /// reading it sees what the strip renders. Its own copy of
    /// the rule returned splice coordinates while the run drew in
    /// fixed slot coordinates, so `first` marked the wrong window
    /// and `before focused` resolved the `+` and the focus to one
    /// slot, where the `+` won the ternary and the run drew no
    /// focused tile at all (#702). With nothing joining, the
    /// incoming slot is `-1` — no index the run draws — and the
    /// focus keeps the middle.
    func focusedSlots(nested: Bool) -> (
        count: Int, incoming: Int, focus: Int
    ) {
        let run = focusedRun
        guard nested else { return (run, -1, (run - 1) / 2) }
        let placed = SchematicPlacement.splice(
            placement,
            count: run,
            focus: (run - 1) / 2
        )
        return (run + 1, placed.incoming, placed.focus)
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
