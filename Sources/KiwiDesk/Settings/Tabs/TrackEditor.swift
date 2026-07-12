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
            // Track is a somewhat more advanced layout
            // (multi-window tracks, caps, per-track resize), so
            // the caption sets that expectation up front (#188).
            // Nothing here is gated.
            Text(
                L(
                    "layout.track.header_caption",
                    "A more advanced layout: several windows can "
                        + "share one track, with a track limit "
                        + "and per-track resize."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
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
            PlacementPicker(
                placement: $model.config.settings.track
                    .newWindowPosition,
                label: L("track.new_window_position", "Position")
            )
            Divider()
            trackAuto
            StepperRow(
                label: L("track.count", "Track limit"),
                value: $model.config.settings.track.count,
                in: 1...10
            )
            .disabled(
                model.config.settings.track.autoTracks
            )
            Divider()
            overflow
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

    /// How the far-edge **overflow track** renders (#192): the
    /// track that collects the surplus when more tracks exist
    /// than fit side by side. `cascade_all` (the default) piles
    /// its windows from the top; `cascade_overflow` tiles the
    /// fitting ones and piles the rest. Normal tracks are always
    /// `cascade_overflow`. Reuses stack's `overflow_style` labels.
    private var overflow: some View {
        DropdownRow(
            label: L("layout_params.overflow", "Overflow")
        ) {
            Picker(
                L("layout_params.overflow", "Overflow"),
                selection: $model.config.settings.track
                    .overflowStyle
            ) {
                Text(
                    L(
                        "layout_params.cascade_overflow",
                        "Cascade overflow"
                    )
                )
                .tag(StackParams.OverflowStyle.cascadeOverflow)
                Text(
                    L(
                        "layout_params.cascade_all",
                        "Cascade all"
                    )
                )
                .tag(StackParams.OverflowStyle.cascadeAll)
            }
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
