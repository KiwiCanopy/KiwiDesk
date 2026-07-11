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
            StepperRow(
                label: L("track.count", "Track limit"),
                value: $model.config.settings.track.count,
                in: 0...10
            )
            Text(
                L(
                    "track.count_caption",
                    "0 means dynamic: tracks open and "
                        + "collapse as windows come and go."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
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
}
