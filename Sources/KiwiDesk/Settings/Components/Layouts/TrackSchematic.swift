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
/// A limit shows that many normal tracks; auto-tracks opens them
/// until the display runs out, which on a canvas is the stand-in
/// `LayoutSchematic.trackGeoCap`.
///
/// The **window count** (turn 10) is what opens and collapses
/// tracks, and since #708 it does so by the ENGINE's rules rather
/// than by arithmetic invented here — `TrackSchematic+Fold` owns
/// the loop and cites them. Two consequences a reader of the
/// drawing should know:
///
/// - `focused_track` is **fill-then-spill** (#437), so windows
///   join the focused track only until it is full and then open
///   one beside it. The preview modelled neither half before, and
///   taught a rule the app does not follow.
/// - The far-edge overflow track therefore appears when something
///   overflows and **not at the shipped defaults**, where nothing
///   does. The caption is conditioned on the same answer
///   (`drawsOverflowTrack`), because it used to name that track
///   whether or not the strip drew one.
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

    private var focusIdx: Int { trackCount / 2 }

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
    /// The engine that governs track-mode spawn is really
    /// `Space.insertIntoTrack` (#128/#188), whose `insertOwnTrack`
    /// arm positions among tracks by the same splice rule this
    /// asks for; `LayoutSchematicTrackEngineTests` pins the two
    /// together rather than leaving it to arithmetic. Its
    /// fill-then-spill arm (#437) is *not* modelled here — see
    /// #708.
    private var newTrackIndex: Int {
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

    enum TrackWindow { case plain, focus, new }

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
        let kinds = focusedTrackKinds(nested: nested)
        return axisStack {
            ForEach(kinds.indices, id: \.self) { i in
                trackWindow(kinds[i])
            }
        }
    }

    /// The focused track's tiles, in the order the run draws them.
    ///
    /// This is the line #702 lived on, so it is a value the guard
    /// can read rather than a ternary inside `body`: a correct
    /// `focusedSlots` feeding a wrong pick reproduces the whole
    /// symptom, and reading the tuple alone left that green
    /// (guard-prover, 2026-08-03). `.new` deliberately wins a tie
    /// — but `LayoutSchematicPlacementTests` requires there is
    /// never a tie to win, since swallowing the focus is the bug.
    func focusedTrackKinds(nested: Bool) -> [TrackWindow] {
        let drawn = focusedSlots(nested: nested)
        return (0..<drawn.count).map { i in
            i == drawn.incoming
                ? .new : i == drawn.focus ? .focus : .plain
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

}
