import KiwiDeskCore
import SwiftUI

/// The Shortcuts intent groups (#68 §3.6.1): flat sections,
/// one level of hierarchy — Focus, Move Windows, Size & Float,
/// Switch modes — rendered as plain titled sections (the old
/// double-nested disclosures are gone). Space rows generate
/// from the defined spaces, so adding a space adds its
/// commands. Recording upserts a `.navigation` row keyed by
/// its Lua; clearing removes it.
struct FocusSection: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let spaces: [SpaceID]

    private var icons: [SpaceID: String] {
        model.config.settings.spaceIcons
    }

    var body: some View {
        SettingsSection(L("shortcuts.section.focus", "Focus")) {
            ForEach(KeybindingCatalog.focusDirections) {
                command in
                NavRow(
                    model: model,
                    bindings: $bindings,
                    command: command
                )
            }
            if !spaces.isEmpty {
                Text(L("shortcuts.go_to_space", "Go to space"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                ForEach(
                    KeybindingCatalog.goToSpace(
                        spaces,
                        icons: icons
                    )
                ) { command in
                    NavRow(
                        model: model,
                        bindings: $bindings,
                        command: command
                    )
                }
            }
        }
    }
}

struct MoveWindowsSection: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let spaces: [SpaceID]

    private var icons: [SpaceID: String] {
        model.config.settings.spaceIcons
    }

    var body: some View {
        SettingsSection(
            L("shortcuts.section.move_windows", "Move Windows")
        ) {
            ForEach(KeybindingCatalog.swapDirections) {
                command in
                NavRow(
                    model: model,
                    bindings: $bindings,
                    command: command
                )
            }
            // Track authoring rows (#188): always rendered — no
            // gate. The caption tells newcomers these only matter
            // in the track layout, so unbound rows in another
            // layout don't read as broken.
            Text(
                L(
                    "shortcuts.move_to_track",
                    "Move to track"
                )
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
            Text(
                L(
                    "shortcuts.move_to_track.caption",
                    "Only relevant if you're using the track "
                        + "layout."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            ForEach(
                KeybindingCatalog.moveToTrackRows
                    + KeybindingCatalog.trackSwapRows
            ) { command in
                NavRow(
                    model: model,
                    bindings: $bindings,
                    command: command
                )
            }
            if !spaces.isEmpty {
                Text(
                    L("shortcuts.move_to_space", "Move to space")
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
                ForEach(
                    KeybindingCatalog.moveToSpace(
                        spaces,
                        icons: icons
                    )
                ) { command in
                    NavRow(
                        model: model,
                        bindings: $bindings,
                        command: command
                    )
                }
            }
        }
    }
}

/// Size & Float (#68 §3.5): the per-axis Grow/Shrink rows
/// (#56) and Make floating — plus the reserved slot for the
/// configurable resize step (#58). The step control lands
/// directly above the rows it parameterizes.
struct SizeFloatSection: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]

    var body: some View {
        SettingsSection(
            L("shortcuts.section.size_float", "Size & Float")
        ) {
            ForEach(
                KeybindingCatalog.resizeAndFloat(
                    step: Int(model.config.settings.resizeStep)
                )
            ) {
                command in
                NavRow(
                    model: model,
                    bindings: $bindings,
                    command: command
                )
            }
            Text(sizeFloatCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            // Unsupported-resize cue (#184): the beep when a
            // resize hotkey can't act in the active layout.
            // Default on; users binding resize keys broadly
            // across layouts can mute it.
            Toggle(
                L(
                    "shortcuts.size_float.feedback",
                    "Alert sound when resize can't apply"
                ),
                isOn: $model.config.settings.resizeFeedback
            )
        }
    }

    // A meaning change replaced the old `axes_caption` key
    // (stale since track landed, #128/#183): per
    // docs/translating.md a changed English text gets a NEW
    // key, never a rename — rename-key would carry the stale
    // translations forward as if still valid.
    private var sizeFloatCaption: String {
        L(
            "shortcuts.size_float.layouts_caption",
            "Grow/Shrink only applies in the bsp, stack, "
                + "scrolling, and track layouts; it is a "
                + "no-op in monocle, grid, and floating. "
                + "Width and height resize independently; "
                + "scrolling resizes its slot along the "
                + "scroll axis for both, and in track one "
                + "axis resizes the window's track, the "
                + "other its share within it."
        )
    }
}

/// Switch modes: one row per other mode, binding a
/// `switch_mode` shortcut. Shown only when more than one mode
/// exists.
struct ChangeModesSection: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let modeNames: [String]
    let current: String

    var body: some View {
        SettingsSection(
            L("shortcuts.section.switch_modes", "Switch modes")
        ) {
            ForEach(others, id: \.self) { name in
                NavRow(
                    model: model,
                    bindings: $bindings,
                    command:
                        KeybindingCatalog.switchModeCommand(
                            name
                        )
                )
            }
        }
    }

    private var others: [String] {
        modeNames.filter { $0 != current }
    }
}
