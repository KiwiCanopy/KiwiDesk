import KiwiDeskCore
import SwiftUI

/// Shortcuts & Gestures ▸ Mouse & trackpad (#1726): what the mouse
/// and trackpad do, grouped by where the hand is. Above the layer
/// header, so nothing here reads as per-layer; collapsed on every
/// visit. An entry lands with its feature, never before, and one
/// whose surface is off greys with a pointer to where it turns on.
struct GesturesDrawer: View {
    @ObservedObject var model: SettingsModel
    @State private var expanded = false

    private var settings: TilingSettings { model.config.settings }

    var body: some View {
        SettingsDisclosure(
            SettingsCatalog.shortcuts.gestures,
            chrome: .card,
            isExpanded: $expanded,
            summary: summary
        ) {
            VStack(alignment: .leading, spacing: 10) {
                GestureGroupHeading(
                    title: L(
                        "shortcuts.gestures.group.windows",
                        "On your windows"
                    )
                )
                windowEntries
                GestureGroupHeading(
                    title: L(
                        "shortcuts.gestures.group.shelf",
                        "On the KiwiShelf"
                    )
                )
                GesturesShelfEntries(model: model)
            }
            .environment(
                \.schematicPalette,
                HomeCardPlate.palette(settings)
            )
        }
    }

    private var summary: String {
        L(
            "shortcuts.gestures.summary",
            "Drag windows, and drag and scroll on the KiwiShelf"
        )
    }

    @ViewBuilder private var windowEntries: some View {
        GestureEntry(
            L(
                "shortcuts.gestures.swap",
                "Drag a window onto another to swap them, or onto "
                    + "another screen to move it there."
            )
        ) { GesturePicture.Swap(t: $0) }
        GestureEntry(
            L(
                "shortcuts.gestures.edge",
                "Drag a window's edge to resize it."
            )
        ) {
            GesturePicture.Edge(t: $0)
        } control: {
            MouseResizePicker(
                selection: $model.config.settings.mouseResize
            )
            .searchAnchored(
                SettingsCatalog.shortcuts.gestures.children
                    .mouseResize
            )
        }
        GestureEntry(
            L(
                "shortcuts.gestures.follow_focus",
                "The pointer can jump to the window that gets "
                    + "focus — from a shortcut, a Space switch, "
                    + "switching apps or a closed window."
            )
        ) {
            GesturePicture.FollowFocus(t: $0)
        } control: {
            Toggle(
                L(
                    "behavior.mouse.follows_focus",
                    "Move mouse to focused window"
                ),
                isOn: $model.config.settings.mouse.followsFocus
            )
            .searchAnchored(
                SettingsCatalog.shortcuts.gestures.children
                    .followsFocus
            )
        }
    }
}

/// The Mouse resize action picker, moved from Behavior ▸ Mouse
/// with #1726; its keys keep their `behavior.mouse.*` names.
struct MouseResizePicker: View {
    @Binding var selection: MouseResizeMode

    var body: some View {
        SegmentedPicker(
            L("behavior.mouse.resize_action", "Mouse resize action"),
            selection: $selection,
            options: [
                (layoutLabel, MouseResizeMode.layout),
                (snapBackLabel, .snapBack),
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
    }

    private var layoutLabel: String {
        L("behavior.mouse.resize_layout", "Resize adjacent windows")
    }

    private var snapBackLabel: String {
        L("behavior.mouse.resize_snap_back", "Snap back to slot")
    }
}
