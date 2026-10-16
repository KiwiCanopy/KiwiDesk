import KiwiDeskCore
import SwiftUI

/// Shortcuts & Gestures ▸ Mouse & trackpad (#1726): what the mouse
/// and trackpad do, grouped by where the hand is. Above the layer
/// header, so nothing here reads as per-layer; a collapsible
/// section card (#1741), collapsed on every visit. An entry lands
/// with its feature, never before, and one whose surface is off
/// greys with a pointer to where it turns on. The user's own click
/// open plays the first picture once per visit (owner ruling
/// 2026-09-29); a search, Go to or its jump chip (#1520) opens it
/// without. It mounts
/// inside the section's `keybindingLayerName` scope, so a gesture
/// recorder (#1656, #1519) must never read that value: a gesture modifier
/// belongs to no layer.
struct GesturesDrawer: View {
    @ObservedObject var model: SettingsModel
    /// The section's, so its jump chip can open the card (#1520).
    @Binding var expanded: Bool
    /// Per visit, like `expanded`: the first click open arms the
    /// first entry's play, which spends it.
    @State private var played = false
    @State private var autoplay = false

    private var settings: TilingSettings { model.config.settings }

    var body: some View {
        SettingsCollapsibleSection(
            SettingsCatalog.shortcuts.gestures,
            isExpanded: $expanded,
            summary: summary,
            onToggle: { open in
                autoplay = open && !played
                if open { played = true }
            }
        ) {
            VStack(alignment: .leading, spacing: 10) {
                GestureGroupHeading(
                    title: L(
                        "shortcuts.gestures.group.scroll",
                        "Scroll gestures — anywhere, holding a modifier"
                    )
                )
                GesturesScrollEntries(model: model, autoplay: $autoplay)
                GestureRule()
                GestureGroupHeading(
                    title: L(
                        "shortcuts.gestures.group.focus",
                        "Focus and the pointer"
                    ),
                    followsGroup: true
                )
                focusEntries
                GestureRule()
                GestureGroupHeading(
                    title: L(
                        "shortcuts.gestures.group.windows",
                        "On your windows"
                    ),
                    followsGroup: true
                )
                windowEntries
                GestureRule()
                GestureGroupHeading(
                    title: L(
                        "shortcuts.gestures.group.shelf",
                        "On the KiwiShelf"
                    ),
                    followsGroup: true
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
            "Scroll gestures, focus where the pointer rests, "
                + "whether the pointer follows focus, and mouse "
                + "resize"
        )
    }

    @ViewBuilder private var windowEntries: some View {
        GestureEntry(
            L(
                "shortcuts.gestures.swap",
                "Drag a window onto another to swap them, or onto "
                    + "another screen to move it there."
            ),
            surface: .windows,
            settings: settings,
            pace: .story
        ) { GesturePicture.Swap(t: $0) }
        GestureRule()
        GestureEntry(
            L(
                "shortcuts.gestures.edge",
                "Drag a window's edge to resize it."
            ),
            surface: .windows,
            settings: settings,
            help: MouseResizePicker.help,
            helpSubject: MouseResizePicker.spokenLabel
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
    }

    /// Hover focus, then its inverse: the hand acts, then the
    /// pointer follows (#1869).
    @ViewBuilder private var focusEntries: some View {
        GestureEntry(
            L(
                "shortcuts.gestures.hover_focus",
                "Rest the pointer on a window to focus it and bring "
                    + "it to the front."
            ),
            surface: .windows,
            settings: settings,
            pace: .steps,
            help: Self.hoverFocusHelp,
            helpSubject: Self.hoverFocusLabel
        ) {
            GesturePicture.HoverFocus(t: $0)
        } control: {
            Toggle(
                Self.hoverFocusLabel,
                isOn: $model.config.settings.mouse.hoverFocus
            )
            .searchAnchored(
                SettingsCatalog.shortcuts.gestures.children
                    .hoverFocus
            )
        }
        GestureRule()
        GestureEntry(
            L(
                "shortcuts.gestures.follow_focus",
                "Focus moves with a shortcut, a Space switch, "
                    + "switching apps or a closed window."
            ),
            surface: .windows,
            settings: settings,
            pace: .steps
        ) {
            GesturePicture.FollowFocus(t: $0)
        } control: {
            Toggle(
                L(
                    "behavior.mouse.follows_focus",
                    "Move the pointer to the window that gets focus"
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

extension GesturesDrawer {
    static var hoverFocusLabel: String {
        L(
            "behavior.mouse.hover_focus",
            "Focus the window the pointer rests on"
        )
    }

    /// The `?` the hover focus entry carries: the one place it
    /// stands down that a user would not expect (#1869).
    static var hoverFocusHelp: String {
        L(
            "behavior.mouse.hover_focus.help",
            "In a scrolling layout, a window only partly on screen "
                + "isn't focused by resting on it, so the row never "
                + "moves under the pointer — click it, or its item in "
                + "the App Bar or Space Bar, to bring it in."
        )
    }
}

/// The Mouse resize action picker, moved from Behavior ▸ Mouse
/// with #1726; its keys keep their `behavior.mouse.*` names.
struct MouseResizePicker: View {
    @Binding var selection: MouseResizeMode

    /// No visible label: the entry's sentence names the control,
    /// and its `?` sits after that sentence (`help`). The label
    /// key names it for VoiceOver and for the census.
    var body: some View {
        SegmentedPicker(
            spokenLabel: Self.spokenLabel,
            hugsLabels: true,
            selection: $selection,
            options: [
                (layoutLabel, MouseResizeMode.layout),
                (snapBackLabel, .snapBack),
            ]
        )
    }

    static var spokenLabel: String {
        L("behavior.mouse.resize_action", "Mouse resize action")
    }

    /// The options, explained: the `?` the edge entry's sentence
    /// carries.
    static var help: String {
        L(
            "behavior.mouse.resize_action.help",
            "**%1$@** — Dragging a "
                + "window's edge resizes it and reflows "
                + "its neighbours in the layout.\n**%2$@**"
                + " — The window resizes "
                + "freely while you drag, then snaps back "
                + "to its tiled size when you release.",
            L("behavior.mouse.resize_layout", "Resize adjacent windows"),
            L("behavior.mouse.resize_snap_back", "Snap back to slot")
        )
    }

    private var layoutLabel: String {
        L("behavior.mouse.resize_layout", "Resize adjacent windows")
    }

    private var snapBackLabel: String {
        L("behavior.mouse.resize_snap_back", "Snap back to slot")
    }
}
