import KiwiDeskCore
import SwiftUI

/// The Track row builders (see `LayoutCard+Rows` for the
/// dispatch and the shared bindings).
extension LayoutCard {
    /// "Arrange: Columns / Rows" (#217 pattern, applied to
    /// Track): "horizontal/vertical" is ambiguous for a two-axis
    /// subdivision layout, so the GUI label names the window
    /// arrangement instead. GUI label only — the Lua/JSON
    /// `track.axis` wire stays geometric, which is unambiguous in
    /// a scripting context (see design-decisions "geometric wire,
    /// presentational label"). Reuses Grid's shared
    /// `scroll_grid.arrange` label; Track's options are bare
    /// "Columns"/"Rows" (no fill-order "first" — Track has no
    /// growth semantic, unlike Grid).
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

    /// How the far-edge **overflow track** renders (#192): the
    /// track that collects the surplus when more tracks exist
    /// than fit side by side. `cascade_all` (the default) piles
    /// its windows from the top; `cascade_overflow` tiles the
    /// fitting ones and piles the rest. Normal tracks are always
    /// `cascade_overflow`. Reuses stack's `overflow_style` labels.
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

    /// The auto-track-limit toggle gating the Track limit
    /// stepper, through the same `AutoGatedGroup` the Grid
    /// dimensions use. On (the default), tracks open and collapse
    /// with the window count and the stepper greys; off pins the
    /// limit.
    ///
    /// Labelled "Auto track limit", not "Automatic tracks"
    /// (R6/#406, ui-designer): no track is itself automatic —
    /// only HOW MANY exist is — so the label names the field it
    /// gates, matching the other `AutoGatedGroup` pairs ("Auto
    /// item size" over "Item size").
    ///
    /// The pair used to be a hand-built toggle-plus-caption above
    /// a separately-`disabled` stepper, which is this component's
    /// job spelled a third way (#233's whole argument).
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
            gatedIsInert:
                gates
                .inertReason(for: .layout(.trackLimit)) != nil
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
