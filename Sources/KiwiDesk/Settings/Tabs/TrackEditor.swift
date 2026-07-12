import KiwiDeskCore
import SwiftUI

/// Track tuning (#128): axis, track limit, where new windows
/// open, and the focus-wrap toggle — the `MonocleEditor`
/// single-section precedent. Track sizes and in-track shares
/// are resize state, not defaults, so they have no rows here.
struct TrackEditor: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        SettingsSection(
            L("layout.track.name", "Track"),
            symbol: LayoutMode.track.glyph
        ) {
            SegmentedPicker(
                L("track.axis", "Axis"),
                selection: $model.config.settings.track.axis,
                options: [
                    (
                        L(
                            "track.axis.vertical",
                            "Vertical (columns)"
                        ),
                        TrackParams.Axis.vertical
                    ),
                    (
                        L(
                            "track.axis.horizontal",
                            "Horizontal (rows)"
                        ),
                        .horizontal
                    ),
                ]
            )
            Divider()
            trackAuto
            StepperRow(
                label: L("track.count", "Track limit"),
                value: $model.config.settings.track.count,
                in: 1...10
            )
            .disabled(model.config.settings.track.autoTracks)
            Divider()
            SegmentedPicker(
                L("track.new_window", "New window"),
                selection: $model.config.settings.track
                    .newWindow,
                options: [
                    (
                        L(
                            "track.new_window.own",
                            "Opens its own track"
                        ),
                        TrackParams.NewWindowTrack.ownTrack
                    ),
                    (
                        L(
                            "track.new_window.focused",
                            "Joins the focused track"
                        ),
                        .focusedTrack
                    ),
                ]
            )
            SegmentedPicker(
                L("layout_params.overflow", "Overflow"),
                selection: $model.config.settings.track
                    .overflowStyle,
                options: [
                    (
                        L(
                            "layout_params.cascade_overflow",
                            "Cascade overflow"
                        ),
                        StackParams.OverflowStyle
                            .cascadeOverflow
                    ),
                    (
                        L(
                            "layout_params.cascade_all",
                            "Cascade all"
                        ),
                        .cascadeAll
                    ),
                ]
            )
            Divider()
            // Bare behavior toggle in its own slot — the #168
            // placement mirrored from the Scrolling section.
            // Off by default — see `TrackParams.wrapFocus`.
            Toggle(
                L("track.wrap_focus", "Wrap focus"),
                isOn: $model.config.settings.track.wrapFocus
            )
        }
    }

    /// The automatic-tracks toggle with its caption. On (the
    /// default), tracks open and collapse with the window count
    /// and the Track limit stepper below greys out; off pins the
    /// count. The track twin of the grid's "Auto-size grid".
    private var trackAuto: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(
                L("track.auto_tracks", "Automatic tracks"),
                isOn: $model.config.settings.track.autoTracks
            )
            Text(
                L(
                    "track.auto_tracks_caption",
                    "Opens and collapses tracks automatically "
                        + "as windows come and go."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
