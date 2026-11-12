import KiwiDeskCore
import SwiftUI

/// Shortcuts ▸ Mouse & Trackpad (#1726, #3184): what the mouse and
/// trackpad do, in open groups ordered by where the hand is — on
/// your windows, holding a modifier, on the KiwiShelf. An entry
/// lands with its feature, never before, and one whose surface is
/// off greys with a pointer to where it turns on. The user's own
/// click on the part plays the first picture once per visit (owner
/// ruling 2026-09-29); a search or Go to lands without. It mounts
/// inside the section's `keybindingLayerName` scope, so a gesture
/// recorder (#1656, #1519) must never read that value: a gesture
/// modifier belongs to no layer.
struct GesturesPart: View {
    @ObservedObject var model: SettingsModel
    /// The section's, set by a click on the segment; spent here.
    @Binding var playArmed: Bool
    /// The entry that plays once as it appears, spending this.
    @State private var playing: GestureItem?

    private var settings: TilingSettings { model.config.settings }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(SettingsCatalog.shortcuts.gesturesOnWindows) {
                focusEntries
                GestureRule()
                windowEntries
            }
            SettingsSection(SettingsCatalog.shortcuts.gesturesModifier) {
                GesturesScrollEntries(model: model, playing: $playing)
            }
            SettingsSection(SettingsCatalog.shortcuts.gesturesOnShelf) {
                GesturesShelfEntries(model: model, playing: $playing)
            }
        }
        .platePaint(settings)
        .searchAnchored(SettingsCatalog.shortcuts.gestures.control)
        .onAppear {
            guard playArmed else { return }
            playArmed = false
            playing = GestureItem.allCases.first
        }
    }

    /// Hover focus, then its inverse: the hand acts, then the
    /// pointer follows (#1869).
    @ViewBuilder private var focusEntries: some View {
        GestureEntry(
            .hoverFocus,
            settings: settings,
            gestures: model.config.scrollGesture,
            help: Self.hoverFocusHelp,
            helpSubject: Self.hoverFocusLabel,
            playing: $playing
        ) {
            VStack(alignment: .leading, spacing: 6) {
                Toggle(
                    Self.hoverFocusLabel,
                    isOn: $model.config.settings.mouse.hoverFocus
                )
                .searchAnchored(
                    SettingsCatalog.shortcuts.gestures.children
                        .hoverFocus
                )
                hoverDelayRow
            }
        }
        .gestureAnchored(.hoverFocus)
        GestureRule()
        GestureEntry(
            .followFocus,
            settings: settings,
            gestures: model.config.scrollGesture,
            playing: $playing
        ) {
            Toggle(
                L(
                    "behavior.mouse.follows_focus",
                    "Pointer follows focus"
                ),
                isOn: $model.config.settings.mouse.followsFocus
            )
            .searchAnchored(
                SettingsCatalog.shortcuts.gestures.children
                    .followsFocus
            )
        }
        .gestureAnchored(.followFocus)
    }

    @ViewBuilder private var windowEntries: some View {
        GestureEntry(
            .swap,
            settings: settings,
            gestures: model.config.scrollGesture,
            playing: $playing
        )
        .gestureAnchored(.swap)
        GestureRule()
        GestureEntry(
            .edge,
            settings: settings,
            gestures: model.config.scrollGesture,
            help: MouseResizePicker.help,
            helpSubject: MouseResizePicker.spokenLabel,
            playing: $playing
        ) {
            MouseResizePicker(
                selection: $model.config.settings.mouseResize
            )
            .searchAnchored(
                SettingsCatalog.shortcuts.gestures.children
                    .mouseResize
            )
        }
        .gestureAnchored(.edge)
    }
}

extension GesturesPart {
    /// How long the pointer rests first (#2379): indented under the
    /// switch it depends on, greyed — never hidden — while it is off.
    var hoverDelayRow: some View {
        StepperRow(
            label: L("behavior.mouse.hover_focus_delay", "Hover delay"),
            value: $model.config.settings.mouse.hoverFocusDelayMS,
            in: Self.hoverDelayRange,
            step: 50,
            suffix: L("behavior.mouse.milliseconds", "ms")
        )
        .fixedSize()
        .disabled(!model.config.settings.mouse.hoverFocus)
        .padding(.leading, 20)
        .searchAnchored(
            SettingsCatalog.shortcuts.gestures.children.hoverFocusDelay
        )
    }

    /// Core's floor; the ceiling is the GUI's curated edge, Lua
    /// free to go past it.
    static var hoverDelayRange: ClosedRange<Int> {
        MouseSettings.hoverFocusDelayFloorMS...2000
    }

    static var hoverFocusLabel: String {
        L(
            "behavior.mouse.hover_focus",
            "Focus follows the pointer"
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
