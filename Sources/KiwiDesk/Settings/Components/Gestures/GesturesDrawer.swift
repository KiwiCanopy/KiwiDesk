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
    /// first entry's play, a picture's click its own entry's, and
    /// the entry that plays spends it.
    @State private var played = false
    @State private var playing: GestureItem?

    private var settings: TilingSettings { model.config.settings }

    var body: some View {
        SettingsCollapsibleSection(
            SettingsCatalog.shortcuts.gestures,
            isExpanded: $expanded,
            summary: summary,
            preview: AnyView(strip),
            onToggle: { open in
                if open, !played { playing = .scrollStep }
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
                GesturesScrollEntries(model: model, playing: $playing)
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
                GesturesShelfEntries(model: model, playing: $playing)
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
            "Scroll with held keys, focus by pointing, drag and "
                + "resize windows, and click or drag on the KiwiShelf"
        )
    }

    /// The shut card's pictures; a click opens the card at that
    /// entry and plays it once, spending the visit's first play.
    private var strip: some View {
        GestureStrip(
            settings: settings,
            gestures: model.config.scrollGesture
        ) { item in
            playing = item
            played = true
            expanded = true
            model.nav.pendingReveal = SettingsAnchor(
                destination: .shortcuts,
                anchor: item.anchor
            )
        }
        .environment(
            \.schematicPalette,
            HomeCardPlate.palette(settings)
        )
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
                    "Move the pointer to the window that gets focus"
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
}

extension GesturesDrawer {
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
