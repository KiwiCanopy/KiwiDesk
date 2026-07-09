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

/// Size & Float (#68 §3.5): the resize pair, Make floating —
/// and the reserved slot for the configurable resize step
/// (#58; grows to a per-axis pair when #56 splits resize into
/// horizontal/vertical). The step control lands directly
/// above the rows it parameterizes.
struct SizeFloatSection: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]

    var body: some View {
        SettingsSection(
            L("shortcuts.section.size_float", "Size & Float")
        ) {
            ForEach(KeybindingCatalog.resizeAndFloat) {
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
        }
    }

    private var sizeFloatCaption: String {
        L(
            "shortcuts.size_float.caption",
            "Shrink/Enlarge only applies in the bsp, "
                + "stack, and scrolling layouts; it is a "
                + "no-op in monocle, grid, and floating. "
                + "It nudges the one split/master ratio, "
                + "so it has no separate width and height."
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

/// A single catalog row: label plus a recorder that upserts a
/// `.navigation` binding keyed by the command's Lua. The
/// preflight hard-blocks combos already held by another row
/// (#34); the row id feeds "Go to" (#68 §3.6.2).
struct NavRow: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let command: NavCommand
    @Environment(\.keybindingOverrideBase)
    private var overrideBase

    var body: some View {
        HStack {
            if let glyph = command.icon, !glyph.isEmpty {
                IconGlyphLabel(icon: glyph)
                    .frame(width: 18)
            }
            Text(command.resolvedLabel)
            Spacer()
            KeyRecorderField(
                combo: index.map { bindings[$0].combo } ?? "",
                conflict: conflict,
                preflight: preflight,
                onRecord: record,
                onClear: clear
            )
        }
        .keybindingRowStyle(inherited: isInherited)
        .id(command.lua)
    }

    private var index: Int? {
        bindings.firstIndex {
            $0.kind == .navigation && $0.lua == command.lua
        }
    }

    /// Override mode: bound-and-equal to the base row, or
    /// unbound on both sides. Always false while editing live.
    private var isInherited: Bool {
        guard let base = overrideBase else { return false }
        if let index {
            return bindings[index].isInherited(from: base)
        }
        return !base.contains {
            $0.kind == .navigation && $0.lua == command.lua
        }
    }

    private var conflict: String? {
        guard let index else { return nil }
        return KeybindingConflicts.text(
            for: bindings[index],
            in: bindings
        )
    }

    private func preflight(
        _ combo: String
    ) -> RecorderRejection? {
        RecorderPreflight.rejection(
            combo: combo,
            excluding: { [lua = command.lua] in
                $0.kind == .navigation && $0.lua == lua
            },
            bindings: $bindings,
            commit: record
        )
    }

    private func record(_ combo: String) {
        if let index {
            bindings[index].combo = combo
        } else {
            bindings.append(
                KeyBinding(
                    combo: combo,
                    lua: command.lua,
                    kind: .navigation,
                    label: command.label
                )
            )
        }
        if let updated = bindings.first(where: {
            $0.kind == .navigation && $0.lua == command.lua
        }) {
            model.noteRecordedCombo(updated, in: bindings)
        }
    }

    private func clear() {
        if let index { bindings.remove(at: index) }
    }
}
