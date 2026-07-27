import KiwiDeskCore
import SwiftUI

/// Scrolling tuning — one mode's tab in Layout Defaults (#204).
/// Split out of the former `ScrollGridEditor` at the mode
/// boundary; the schematic (#125) leads the section.
struct ScrollingEditor: View {
    @ObservedObject var model: SettingsModel

    /// The scroll axis runs top↔bottom when vertical, so the slot
    /// size reads as a row *height*, and the anchor ends as
    /// top/bottom — labels swap accordingly (frontend only; the
    /// stored `slot_size` / anchor enum are orientation-neutral).
    private var isVertical: Bool {
        model.config.settings.scrolling.orientation == .vertical
    }

    private var scrolling: Binding<ScrollingParams> {
        $model.config.settings.scrolling
    }

    var body: some View {
        SettingsSection(
            SettingsCatalog.layoutMode(.scrolling),
            symbol: LayoutMode.scrolling.glyph
        ) {
            ScrollingSchematic(
                orientation: model.config.settings.scrolling
                    .orientation,
                anchor: model.config.settings.scrolling.anchor,
                slotSize: model.config.settings.scrolling
                    .slotSize,
                placement: model.config.settings.scrolling
                    .newWindowPlacement
            )
            // Order (user): orientation, then anchor, then the
            // size-unit picker — the size *value* control re-homes
            // below the divider.
            SegmentedPicker(
                L(
                    "scroll_grid.scroll_orientation",
                    "Scroll orientation"
                ),
                selection: scrolling.orientation,
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
            SegmentedPicker(
                L("scroll_grid.focus_anchor", "Focus anchor"),
                selection: scrolling.anchor,
                options: [
                    (
                        L("scroll_grid.anchor.center", "Center"),
                        ScrollingParams.Anchor.center
                    ),
                    (
                        // Axis-relative value `.start`; the label
                        // shows the concrete edge for the current
                        // orientation (Top vertical, Left
                        // horizontal — presentation only, #239).
                        isVertical
                            ? L("scroll_grid.anchor.start_v", "Top")
                            : L(
                                "scroll_grid.anchor.start_h",
                                "Left"
                            ), .start
                    ),
                    (
                        isVertical
                            ? L(
                                "scroll_grid.anchor.end_v",
                                "Bottom"
                            )
                            : L(
                                "scroll_grid.anchor.end_h",
                                "Right"
                            ), .end
                    ),
                    (
                        L("scroll_grid.anchor.follow", "Follow"),
                        .follow
                    ),
                ]
            )
            SlotSizeRows(
                model: model,
                size: scrolling.slotSize,
                isVertical: isVertical,
                part: .unit
            )
            Divider()
            // The size value re-homed below the picker trio so
            // the three segmented pickers read as one group and
            // the size control gets its own breathing room.
            SlotSizeRows(
                model: model,
                size: scrolling.slotSize,
                isVertical: isVertical,
                part: .control
            )
            Divider()
            // New-window placement — the engine and Lua
            // (`scroll.set_new_window_placement`) always had this;
            // the picker was just missing from the GUI.
            PlacementPicker(placement: scrolling.newWindowPlacement)
            Divider()
            // Bare behavior toggle (#168), grouped with the
            // section's other plain switches, apart from the
            // geometry pickers and the animation pair. Off by
            // default — see `ScrollingParams.wrapFocus`.
            ToggleRow(
                label: L("scroll_grid.wrap_focus", "Wrap focus"),
                isOn: scrolling.wrapFocus,
                help: LayoutHelp.wrapFocus
            )
            Divider()
            // The scrolling-specific animation pair (#68
            // §3.5): the on/off switch and its magnitude sit
            // together, like a layout's App Bar enable sits
            // above its overrides.
            ToggleRow(
                label: L(
                    "scroll_grid.animate_focus_shifts",
                    "Animate focus shifts"
                ),
                isOn: $model.config.settings.animations
                    .onScrolling,
                help: LayoutHelp.animateFocusShifts
            )
            scrollSpeedRow
            CrossReferenceRow(
                // Live On/Off state inline (design consult): the
                // enable toggle + all styling stay owned by the
                // App Bar tab, but Layout Defaults shows the
                // current state so it isn't a dead pointer.
                prose: L(
                    "scroll_grid.app_bar_xref_state",
                    "The scrolling app bar (currently %1$@) is "
                        + "configured in",
                    barState
                ),
                linkTitle: L(
                    "scroll_grid.app_bar_xref_link",
                    "App Bar"
                ),
                destination: .bars
            )
        }
    }

    private var barState: String {
        model.config.settings.scrolling.appBar.enabled
            ? L("common.on", "on") : L("common.off", "off")
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
}
