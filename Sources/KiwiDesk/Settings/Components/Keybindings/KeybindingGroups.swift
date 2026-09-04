import KiwiDeskCore
import SwiftUI

/// Shortcuts action groups mapped from census definitions
/// (`ShortcutsCensusRenderTests`, #678).

/// Family rows view displaying heading, caption, and navigation rows (#678).
struct KeybindingFamilyRows: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let key: SettingKey
    let expander: ShortcutsFamilyRows
    /// A heading separates a family from its SIBLINGS in a
    /// shared card; a family alone under its own drawer title
    /// has none to separate it from (#1125).
    var showsHeading = true

    var body: some View {
        let commands = renderedRows
        if !commands.isEmpty {
            if showsHeading,
                let heading = ShortcutsFamilyHeading.title(for: key)
            {
                Text(heading)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            if let caption = ShortcutsFamilyHeading.caption(
                for: key
            ) {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if commands.contains(where: {
                $0.unavailable != nil
            }) {
                Text(unavailableNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(commands) { command in
                NavRow(
                    model: model,
                    bindings: $bindings,
                    command: command
                )
            }
        }
    }

    private var renderedRows: [NavCommand] {
        expander.renderedRows(for: key)
    }

    /// Caption for actions targeting temporarily disconnected displays.
    private var unavailableNote: String {
        L(
            "shortcuts.desktop_away",
            "Dimmed rows target a Desktop that isn't on any "
                + "screen right now. Their shortcuts stay "
                + "recorded and work again when it comes back."
        )
    }
}

/// Headings and context captions for shortcut census families (#188).
@MainActor
enum ShortcutsFamilyHeading {
    static func title(for key: SettingKey) -> String? {
        switch key {
        case .shortcuts(.goToSpace):
            return L("shortcuts.go_to_space", "Go to Space")
        case .shortcuts(.moveWindowToTrack):
            return L("shortcuts.move_to_track", "Move to track")
        case .shortcuts(.moveToSpace):
            return L("shortcuts.move_to_space", "Move to Space")
        case .shortcuts(.focusDesktop):
            return L("shortcuts.go_to_desktop", "Go to Desktop")
        case .shortcuts(.moveToDesktop):
            return L(
                "shortcuts.move_to_desktop",
                "Move to Desktop"
            )
        default:
            return nil
        }
    }

    static func caption(for key: SettingKey) -> String? {
        switch key {
        case .shortcuts(.moveWindowToTrack):
            return L(
                "shortcuts.move_to_track.caption",
                "Only relevant if you're using the track "
                    + "layout."
            )
        default:
            return nil
        }
    }
}

struct FocusGroup: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let expander: ShortcutsFamilyRows

    var body: some View {
        SettingsSection(SettingsCatalog.shortcuts.focusKeys) {
            ForEach(ShortcutsRowOrder.focusAtRest, id: \.id) {
                key in
                KeybindingFamilyRows(
                    model: model,
                    bindings: $bindings,
                    key: key,
                    expander: expander
                )
            }
            DesktopShortcutsOffer(
                model: model,
                bindings: $bindings,
                keys: ShortcutsRowOrder.focusDesktopFamilies,
                drawer: SettingsCatalog.shortcuts.focusDesktops,
                expander: expander
            )
        }
    }
}

struct MoveWindowsGroup: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let expander: ShortcutsFamilyRows

    var body: some View {
        SettingsSection(
            SettingsCatalog.shortcuts.moveWindows
        ) {
            ForEach(
                ShortcutsRowOrder.moveWindowsAtRest,
                id: \.id
            ) { key in
                KeybindingFamilyRows(
                    model: model,
                    bindings: $bindings,
                    key: key,
                    expander: expander
                )
            }
            DesktopShortcutsOffer(
                model: model,
                bindings: $bindings,
                keys: ShortcutsRowOrder
                    .moveWindowsDesktopFamilies,
                drawer: SettingsCatalog.shortcuts
                    .moveWindowsDesktops,
                expander: expander
            )
        }
    }
}

/// Size & float shortcut section (#68, #56, #184).
struct SizeFloatGroup: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let expander: ShortcutsFamilyRows

    var body: some View {
        SettingsSection(
            SettingsCatalog.shortcuts.sizeFloat
        ) {
            ForEach(
                ShortcutsRowOrder.sizeAndFloatAtRest,
                id: \.id
            ) { key in
                KeybindingFamilyRows(
                    model: model,
                    bindings: $bindings,
                    key: key,
                    expander: expander
                )
            }
            Text(sizeFloatCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Caption describing resize scope across layouts. It names no
    /// verb (owner ruling 2026-08-29) — quoting the rows' labels is
    /// the #818 drift — and scopes by the dimension: it renders
    /// after SEVEN rows, the four resize ones plus three toggles.
    private var sizeFloatCaption: String {
        L(
            "shortcuts.size_float.layouts_caption",
            "Width and height shortcuts only apply in the "
                + "bsp, stack, "
                + "scrolling, and track layouts; they are a "
                + "no-op in monocle, grid, and floating. "
                + "Width and height resize independently; "
                + "scrolling resizes its slot along the "
                + "scroll axis for both, and in track one "
                + "axis resizes the window's track, the "
                + "other its share within it."
        )
    }
}

/// App-level shortcut hotkeys group (#330, #602).
struct GeneralShortcutsGroup: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let expander: ShortcutsFamilyRows

    @State private var expanded = false

    var body: some View {
        SettingsDisclosure(
            SettingsCatalog.shortcuts.generalKeys,
            chrome: .card,
            isExpanded: $expanded
        ) {
            ForEach(
                ShortcutsRowOrder.generalKeysMore,
                id: \.id
            ) { key in
                KeybindingFamilyRows(
                    model: model,
                    bindings: $bindings,
                    key: key,
                    expander: expander
                )
            }
            .padding(.top, 8)
        }
    }
}
