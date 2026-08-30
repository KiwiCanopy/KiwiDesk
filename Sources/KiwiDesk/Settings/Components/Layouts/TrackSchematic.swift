import KiwiDeskCore
import SwiftUI

/// Track layout schematic displaying track arrangement, focus, and overflow
/// (#125, #708).
struct TrackSchematic: View {
    let axis: TrackParams.Axis
    let overflowStyle: StackParams.OverflowStyle
    let newWindow: TrackParams.NewWindowTrack
    let placement: SpawnPlacement
    let limit: Int
    let autoTracks: Bool
    /// Windows on screen including incoming window.
    var windows = LayoutSchematic.defaultWindowCount
    var scale: SchematicScale = .tile

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    /// Restage animation damping gated by Reduce Motion (#1069).
    private var damping: Animation? {
        reduceMotion ? nil : LayoutSchematic.damping
    }

    private var vertical: Bool { axis == .vertical }

    /// Index of track wearing focus from the engine fold.
    var focusIdx: Int {
        min(max(0, markerTracks.focus), max(0, trackCount - 1))
    }

    struct TrackSpec {
        var focused = false
        var isNew = false
        var nestedNew = false
        /// Number of windows in track from the fold.
        var run = 1
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
                .animation(damping, value: axis)
                .animation(damping, value: overflowStyle)
                .animation(damping, value: newWindow)
                .animation(damping, value: placement)
                .animation(damping, value: limit)
                .animation(damping, value: autoTracks)
                .animation(damping, value: windows)
        }
    }

    /// Track slot indices for incoming and focused tracks
    /// (`LayoutSchematicPlacementTests`).
    var trackSlots: (incoming: Int, focus: Int) {
        let drawn = specs
        return (
            drawn.firstIndex { $0.isNew } ?? -1,
            drawn.firstIndex { $0.focused } ?? -1
        )
    }

    /// Normal tracks with incoming track/window spliced in.
    var specs: [TrackSpec] {
        let counts = markerTracks.counts
        var s = (0..<trackCount).map { index in
            TrackSpec(
                focused: index == focusIdx,
                run: index < counts.count ? counts[index] : 1
            )
        }
        switch newWindow {
        case .focusedTrack:
            s[focusIdx].nestedNew = true
        case .ownTrack:
            s.insert(TrackSpec(isNew: true), at: newTrackIndex)
        }
        return s
    }

    /// Target track splice index via `SchematicPlacement` (#702, #437,
    /// `LayoutSchematicTrackEngineTests`).
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
        if overflowWindows > 0 {
            overflowTrack
        }
    }

    enum TrackWindow { case plain, focus, new }

    /// Clamps track run length for legible schematic rendering.
    func drawnRun(_ run: Int) -> Int { min(4, max(1, run)) }

    @ViewBuilder
    private func trackView(_ spec: TrackSpec) -> some View {
        if spec.isNew {
            SchematicNewWindow()
        } else if spec.focused {
            focusedTrack(nested: spec.nestedNew)
        } else {
            axisStack {
                ForEach(0..<drawnRun(spec.run), id: \.self) { _ in
                    SchematicTile()
                }
            }
        }
    }

    /// Focused track containing primary focus and potential nested window.
    private func focusedTrack(nested: Bool) -> some View {
        let kinds = focusedTrackKinds(nested: nested)
        return axisStack {
            ForEach(kinds.indices, id: \.self) { i in
                trackWindow(kinds[i])
            }
        }
    }

    /// Ordered tiles in focused track (`LayoutSchematicPlacementTests`, #702).
    func focusedTrackKinds(nested: Bool) -> [TrackWindow] {
        let drawn = focusedSlots(nested: nested)
        return (0..<drawn.count).map { i in
            i == drawn.incoming
                ? .new : i == drawn.focus ? .focus : .plain
        }
    }

    /// Drawn slot coordinates and placement indices for focused track (#702).
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
