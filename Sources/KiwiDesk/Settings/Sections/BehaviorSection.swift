import AppKit
import KiwiDeskCore
import SwiftUI

/// Profile Behavior settings section (#68 §3.2, #678 Phase 3).
struct BehaviorSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                mouseSection
                cuesSection
                quitSection
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
    }

    /// The refusal cue's audible half (#1255). A draft setting
    /// like its neighbours here, so it lands on Save — but it
    /// PREVIEWS on switch-on, the way macOS's own alert-sound
    /// picker does: this area draws no live preview panel, and a
    /// sound is the one cue a panel could not show anyway.
    /// Nothing is applied by the preview; the draft still saves.
    private var cuesSection: some View {
        SettingsSection(SettingsCatalog.behavior.cuesCard) {
            Toggle(
                // The card title already states the condition,
                // so the label names only what is switched —
                // "When an action can't apply ▸ Play a sound
                // when an action can't apply" read as a stutter
                // in every catalog, the English being the title
                // with four words in front of it.
                L(
                    "behavior.cues.sound",
                    "Play the system alert sound"
                ),
                isOn: Binding(
                    get: { model.config.settings.refusalSound },
                    set: { on in
                        model.config.settings.refusalSound = on
                        if on { NSSound.beep() }
                    }
                )
            )
            Text(
                L(
                    "behavior.cues.sound.help",
                    "A blocked action always shows a message on "
                        + "the window — at a size limit, or where "
                        + "the layout has nothing to resize. This "
                        + "adds the system alert sound to it."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var mouseSection: some View {
        SettingsSection(SettingsCatalog.behavior.mouseCard) {
            SegmentedPicker(
                L(
                    "behavior.mouse.resize_action",
                    "Mouse resize action"
                ),
                selection: $model.config.settings
                    .mouseResize,
                options: [
                    (
                        L(
                            "behavior.mouse.resize_layout",
                            "Resize adjacent windows"
                        ),
                        MouseResizeMode.layout
                    ),
                    (
                        L(
                            "behavior.mouse.resize_snap_back",
                            "Snap back to slot"
                        ), .snapBack
                    ),
                ],
                help: L(
                    "behavior.mouse.resize_action.help",
                    "**%1$@** — Dragging a "
                        + "window's edge resizes it and reflows "
                        + "its neighbours in the layout.\n**%2$@**"
                        + " — The window resizes "
                        + "freely while you drag, then snaps back "
                        + "to its tiled size when you release.",
                    L(
                        "behavior.mouse.resize_layout",
                        "Resize adjacent windows"
                    ),
                    L(
                        "behavior.mouse.resize_snap_back",
                        "Snap back to slot"
                    )
                )
            )
            Toggle(
                L(
                    "behavior.mouse.follows_focus",
                    "Move mouse to focused window"
                ),
                isOn: $model.config.settings.mouse
                    .followsFocus
            )
        }
    }

    /// On quit (#281): the quit grid's density target
    /// (`quit.grid_target_depth`). Grid dimensions stay
    /// automatic (2×2…4×4); no layout picker while `grid` is
    /// the only strategy.
    private var quitSection: some View {
        SettingsSection(
            SettingsCatalog.behavior.quitCard,
            caption: L(
                "behavior.quit.caption",
                "Before KiwiDesk stops, it arranges managed "
                    + "windows on each display so their title "
                    + "bars remain reachable."
            )
        ) {
            StepperRow(
                label: L(
                    "behavior.quit.target_depth",
                    "Target windows per cell"
                ),
                value: $model.config.settings
                    .quitGridTargetDepth,
                in: QuitGridLayout.targetDepthRange,
                help: L(
                    "behavior.quit.target_depth.help",
                    "The grid adds a row and column when "
                        + "cells would exceed this target. It "
                        + "stays between 2×2 and 4×4; "
                        + "after 4×4, additional windows keep "
                        + "cascading in its cells."
                )
            )
            gridSummary
        }
    }

    /// Neutral live summary of the thresholds the current
    /// target produces: dimension grows past 4T and 9T.
    private var gridSummary: some View {
        let target = model.config.settings
            .quitGridTargetDepth
        return Text(
            L(
                "behavior.quit.summary",
                "2×2 up to %1$d windows · 3×3 up to %2$d · "
                    + "4×4 above %2$d",
                4 * target,
                9 * target
            )
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
