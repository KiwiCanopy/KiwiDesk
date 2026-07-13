import KiwiDeskCore
import SwiftUI

/// The Track schematic (#125): a fixed two-track illustration —
/// it teaches the *shape*, not the track count (the limit and
/// automatic-tracks are magnitudes, stated in their captions, not
/// drawn: a count-driven diagram read as a number statement).
///
/// Tracks run along the staged `axis`, the focused one in a
/// heavier stroke, the far one piling its overflow. Track's
/// defining knob — where a new window goes — is the dense
/// **new-window tile**: a whole new track when new windows open
/// their own, or a tile nested inside the focused track when they
/// join it. The two shapes read apart at a glance.
struct TrackSchematic: View {
    let axis: TrackParams.Axis
    let overflowStyle: StackParams.OverflowStyle
    let newWindow: TrackParams.NewWindowTrack

    private var vertical: Bool { axis == .vertical }

    var body: some View {
        SchematicCanvas(caption: caption, axLabel: axLabel) {
            strip
                .animation(LayoutSchematic.damping, value: axis)
                .animation(
                    LayoutSchematic.damping,
                    value: overflowStyle
                )
                .animation(
                    LayoutSchematic.damping,
                    value: newWindow
                )
        }
    }

    @ViewBuilder
    private var strip: some View {
        if vertical {
            HStack(spacing: 3) { tracks }
        } else {
            VStack(spacing: 3) { tracks }
        }
    }

    @ViewBuilder
    private var tracks: some View {
        focusedTrack
        overflowTrack
        if newWindow == .ownTrack {
            // A new window opens its own track: a whole dense
            // new-window track at the far end.
            SchematicNewWindow()
        }
    }

    /// The focused track. When new windows join it, it carries a
    /// nested new-window tile — the small-nested shape reads apart
    /// from a whole new-window track.
    @ViewBuilder
    private var focusedTrack: some View {
        if newWindow == .focusedTrack {
            if vertical {
                VStack(spacing: 2) {
                    SchematicTile(active: true)
                    SchematicNewWindow()
                }
            } else {
                HStack(spacing: 2) {
                    SchematicTile(active: true)
                    SchematicNewWindow()
                }
            }
        } else {
            SchematicTile(active: true)
        }
    }

    /// The far-edge overflow track piling its windows; cascade-all
    /// fans wider than cascade-overflow.
    private var overflowTrack: some View {
        let step: CGFloat = overflowStyle == .cascadeAll ? 8 : 4
        return ZStack {
            SchematicTile()
            SchematicTile()
                .padding(
                    .init(
                        top: step,
                        leading: step,
                        bottom: 0,
                        trailing: 0
                    )
                )
        }
    }

    private var caption: String {
        switch newWindow {
        case .ownTrack:
            return L(
                "layout.schematic.track.caption_own",
                "New windows open their own track."
            )
        case .focusedTrack:
            return L(
                "layout.schematic.track.caption_focused",
                "New windows join the track you're viewing."
            )
        }
    }

    private var axLabel: String {
        L(
            "layout.schematic.track.ax",
            "Track preview: tracks along one axis, the far one "
                + "collecting overflow; the bold tile is the "
                + "next window."
        )
    }
}
