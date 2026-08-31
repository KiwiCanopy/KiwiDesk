import KiwiDeskCore
import SwiftUI

/// Track layout settings row builders (`LayoutCard+Rows`).
extension LayoutCard {
    /// Track arrange row (Columns / Rows, #217).
    var trackArrangeRow: some View {
        SegmentedPicker(
            L("scroll_grid.arrange", "Arrange"),
            selection: track.axis,
            options: [
                (
                    L("scroll_grid.arrange.columns", "Columns"),
                    TrackParams.Axis.vertical
                ),
                (
                    L("scroll_grid.arrange.rows", "Rows"),
                    .horizontal
                ),
            ]
        )
    }

    /// Overflow track rendering style picker
    /// (`TrackParams.OverflowStyle`, #192).
    var trackOverflowRow: some View {
        SegmentedPicker(
            L("layout_params.overflow", "Overflow"),
            selection: track.overflowStyle,
            options: overflowOptions,
            help: LayoutHelp.trackOverflow
        )
    }

    var trackNewWindowRow: some View {
        SegmentedPicker(
            L("track.new_window", "New window"),
            selection: track.newWindow,
            options: [
                (
                    L(
                        "track.new_window.focused",
                        "Fills the focused track"
                    ),
                    TrackParams.NewWindowTrack.focusedTrack
                ),
                (
                    L("track.new_window.own", "Opens its own track"),
                    .ownTrack
                ),
            ]
        )
    }

    var trackPositionRow: some View {
        PlacementPicker(
            placement: track.newWindowPosition,
            label: L("track.new_window_position", "Position"),
            help: LayoutHelp.trackPosition
        )
    }

    /// Track limit inert reason derived from layout gates.
    var trackLimitReason: LayoutDefaultsGates.InertReason? {
        gates.inertReason(for: .layout(.trackLimit))
    }

    /// Auto track limit group gating track limit stepper
    /// (`AutoGatedGroup`, #233, #406).
    var trackLimitGroup: some View {
        AutoGatedGroup(
            title: L("track.auto_tracks", "Auto track limit"),
            isOn: track.autoTracks,
            caption: L(
                "track.auto_tracks_caption",
                "Fits as many tracks as the screen allows, using "
                    + "the minimum window size above — opening and "
                    + "collapsing them as windows come and go."
            ),
            gatedIsInert: trackLimitReason != nil,
            gatedHelp: trackLimitReason.map(
                LayoutDefaultsGateHelp.sentence
            ) ?? ""
        ) {
            StepperRow(
                label: L("track.limit", "Track limit"),
                value: track.limit,
                in: 1...10
            )
        }
    }

    var trackWrapFocusRow: some View {
        ToggleRow(
            label: L("track.wrap_focus", "Wrap focus"),
            isOn: track.wrapFocus,
            help: LayoutHelp.wrapFocus
        )
    }
}
