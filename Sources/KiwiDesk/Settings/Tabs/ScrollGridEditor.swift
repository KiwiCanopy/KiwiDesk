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
            "Scrolling",
            symbol: LayoutMode.scrolling.glyph
        ) {
            SlotSizeRows(model: model, isVertical: isVertical)
            SegmentedPicker(
                "Focus anchor",
                selection: $model.config.settings.scrolling
                    .anchor,
                options: [
                    ("Center", ScrollingParams.Anchor.center),
                    (isVertical ? "Top" : "Left", .left),
                    (isVertical ? "Bottom" : "Right", .right),
                ]
            )
            SegmentedPicker(
                "Scroll orientation",
                selection: $model.config.settings.scrolling
                    .orientation,
                options: [
                    (
                        "Horizontal",
                        ScrollingParams.Orientation.horizontal
                    ),
                    ("Vertical", .vertical),
                ]
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
                "Animate focus shifts",
                isOn: $model.config.settings.animations
                    .onScrolling
            )
            scrollSpeedRow
            CrossReferenceRow(
                prose: "The app bar shown in scrolling is "
                    + "configured in",
                linkTitle: "Appearance ▸ App Bar",
                destination: .appearance
            )
        }
    }

    /// Stepper for the scrolling focus-shift speed
    /// (`animations.scroll_speed`;
    /// `animations.set_scroll_speed` Lua — #51).
    private var scrollSpeedRow: some View {
        let ms = model.config.settings.animations.scrollSpeedMS
        return HStack {
            Text("Scroll speed")
            Spacer()
            Stepper(
                value: $model.config.settings.animations
                    .scrollSpeedMS,
                in: 50...1000,
                step: 10
            ) {
                Text("\(ms) ms")
                    .frame(minWidth: 52, alignment: .trailing)
                    .monospacedDigit()
            }
            .controlSize(.large)
            .accessibilityLabel("Scroll speed")
            .accessibilityValue("\(ms) ms")
        }
        .disabled(
            !model.config.settings.animations.onScrolling
        )
    }

    private var grid: some View {
        SettingsSection(
            "Grid",
            symbol: LayoutMode.grid.glyph
        ) {
            SegmentedPicker(
                "Grid type",
                selection: $model.config.settings.grid.type,
                options: [
                    ("Dynamic", GridParams.GridType.dynamic),
                    ("Rigid", .rigid),
                ]
            )
            Toggle(
                "Fill empty space",
                isOn: $model.config.settings.grid.fillEmptySpace
            )
            SegmentedPicker(
                "Split direction",
                selection: $model.config.settings.grid
                    .splitDirection,
                options: [
                    (
                        "Horizontal",
                        GridParams.SplitDirection.horizontal
                    ),
                    ("Vertical", .vertical),
                ]
            )
            StepperRow(
                label: "Columns",
                value: $model.config.settings.grid.columns,
                in: 1...10
            )
            StepperRow(
                label: "Rows",
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
