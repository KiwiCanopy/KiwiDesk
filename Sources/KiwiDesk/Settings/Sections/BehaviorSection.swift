import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Behavior (#68 §3.2): mouse-resize mode and
/// what happens on quit — per-profile data, labeled as such by
/// the sidebar group (the old General tab presented them without
/// any scope cue).
///
/// The animation toggles left in #678 Phase 3: the census places
/// every one of them in Colours & Motion, and half a card on each
/// page is an area the render-parity guard cannot see whole.
struct BehaviorSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                mouseSection
                quitSection
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
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
                    "**Resize adjacent windows** — Dragging a "
                        + "window's edge resizes it and reflows "
                        + "its neighbours in the layout.\n**Snap "
                        + "back to slot** — The window resizes "
                        + "freely while you drag, then snaps back "
                        + "to its tiled size when you release."
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
