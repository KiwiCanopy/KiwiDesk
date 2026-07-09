import KiwiDeskCore
import SwiftUI

/// Scrolling and Grid tuning (05_GUI_Concept §2, Tab 3).
struct ScrollGridEditor: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            scrolling
            grid
        }
    }

    /// The scroll axis runs top↔bottom when vertical, so the slot
    /// size reads as a row *height*, and the anchor ends as
    /// top/bottom — labels swap accordingly (frontend only; the
    /// stored `slot_size` / anchor enum are orientation-neutral).
    private var isVertical: Bool {
        model.config.settings.scrolling.orientation == .vertical
    }

    private var scrolling: some View {
        SettingsSection(
            L("layout.scrolling.name", "Scrolling"),
            symbol: LayoutMode.scrolling.glyph
        ) {
            SlotSizeRows(
                model: model,
                isVertical: isVertical,
                part: .unit
            )
            SegmentedPicker(
                L("scroll_grid.focus_anchor", "Focus anchor"),
                selection: $model.config.settings.scrolling
                    .anchor,
                options: [
                    (
                        L("scroll_grid.anchor.center", "Center"),
                        ScrollingParams.Anchor.center
                    ),
                    (
                        isVertical
                            ? L("scroll_grid.anchor.top", "Top")
                            : L(
                                "scroll_grid.anchor.left",
                                "Left"
                            ), .left
                    ),
                    (
                        isVertical
                            ? L(
                                "scroll_grid.anchor.bottom",
                                "Bottom"
                            )
                            : L(
                                "scroll_grid.anchor.right",
                                "Right"
                            ), .right
                    ),
                ]
            )
            SegmentedPicker(
                L(
                    "scroll_grid.scroll_orientation",
                    "Scroll orientation"
                ),
                selection: $model.config.settings.scrolling
                    .orientation,
                options: [
                    (
                        L(
                            "scroll_grid.horizontal",
                            "Horizontal"
                        ),
                        ScrollingParams.Orientation.horizontal
                    ),
                    (
                        L("scroll_grid.vertical", "Vertical"),
                        .vertical
                    ),
                ]
            )
            Divider()
            // The size value re-homed below the picker trio so
            // the three segmented pickers read as one group and
            // the size control gets its own breathing room.
            SlotSizeRows(
                model: model,
                isVertical: isVertical,
                part: .control
            )
            Divider()
            PlacementPicker(
                placement: $model.config.settings.scrolling
                    .newWindowPlacement
            )
            Divider()
            // The scrolling-specific animation pair (#68
            // §3.5): the on/off switch and its magnitude sit
            // together, like a layout's App Bar enable sits
            // above its overrides.
            Toggle(
                L(
                    "scroll_grid.animate_focus_shifts",
                    "Animate focus shifts"
                ),
                isOn: $model.config.settings.animations
                    .onScrolling
            )
            scrollSpeedRow
            CrossReferenceRow(
                prose: L(
                    "scroll_grid.app_bar_xref",
                    "The app bar shown in scrolling is "
                        + "configured in"
                ),
                linkTitle: L(
                    "scroll_grid.app_bar_xref_link",
                    "Appearance ▸ App Bar"
                ),
                destination: .appearance
            )
        }
    }

    /// Stepper for the scrolling focus-shift speed
    /// (`animations.scroll_speed`;
    /// `animations.set_scroll_speed` Lua — #51). Reuses the
    /// shared editable `StepperRow` (with a "ms" suffix) rather
    /// than hand-rolling the same shape.
    private var scrollSpeedRow: some View {
        StepperRow(
            label: L("scroll_grid.scroll_speed", "Scroll speed"),
            value: $model.config.settings.animations
                .scrollSpeedMS,
            in: 50...1000,
            step: 10,
            suffix: "ms"
        )
        .disabled(
            !model.config.settings.animations.onScrolling
        )
    }

    private var grid: some View {
        SettingsSection(
            L("layout.grid.name", "Grid"),
            symbol: LayoutMode.grid.glyph
        ) {
            SegmentedPicker(
                L("scroll_grid.grid_type", "Grid type"),
                selection: $model.config.settings.grid.type,
                options: [
                    (
                        L("scroll_grid.dynamic", "Dynamic"),
                        GridParams.GridType.dynamic
                    ),
                    (L("scroll_grid.rigid", "Rigid"), .rigid),
                ]
            )
            SegmentedPicker(
                L(
                    "scroll_grid.split_direction",
                    "Split direction"
                ),
                selection: $model.config.settings.grid
                    .splitDirection,
                options: [
                    (
                        L(
                            "scroll_grid.horizontal",
                            "Horizontal"
                        ),
                        GridParams.SplitDirection.horizontal
                    ),
                    (
                        L("scroll_grid.vertical", "Vertical"),
                        .vertical
                    ),
                ]
            )
            Divider()
            Toggle(
                L(
                    "scroll_grid.fill_empty_space",
                    "Fill empty space"
                ),
                isOn: $model.config.settings.grid.fillEmptySpace
            )
            StepperRow(
                label: L("scroll_grid.columns", "Columns"),
                value: $model.config.settings.grid.columns,
                in: 1...10
            )
            StepperRow(
                label: L("scroll_grid.rows", "Rows"),
                value: $model.config.settings.grid.rows,
                in: 1...10
            )
            Divider()
            PlacementPicker(
                placement: $model.config.settings.grid
                    .newWindowPlacement
            )
        }
    }
}
