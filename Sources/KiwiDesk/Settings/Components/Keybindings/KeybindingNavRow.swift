import KiwiDeskCore
import SwiftUI

/// A single catalog row: label plus a recorder that upserts a
/// `.navigation` binding keyed by the command's Lua. The
/// preflight hard-blocks combos already held by another row
/// (#34); the row id feeds "Go to" (#68 §3.6.2).
///
/// Extracted from `KeybindingGroups` (the shared row every
/// section composes) to keep that file under the size ceiling.
struct NavRow: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let command: NavCommand
    @Environment(\.keybindingOverrideBase)
    private var overrideBase
    @Environment(\.keybindingLayerName)
    private var layerName

    var body: some View {
        HStack {
            // Reserve the icon slot unconditionally (#264): only
            // Go-to/Move-to-space rows carry a glyph, so a
            // conditional icon shifted every icon-less row's
            // label ~18 pt leftward. `Color.clear` holds the
            // width; the glyph draws in an overlay when present.
            Color.clear
                .frame(width: 18)
                .overlay {
                    if let glyph = command.icon,
                        !glyph.isEmpty
                    {
                        IconGlyphLabel(icon: glyph)
                    }
                }
            Text(command.resolvedLabel)
            if let help = command.help {
                HelpButton(
                    explanation: help(),
                    subject: command.resolvedLabel
                )
            }
            Spacer()
            KeyRecorderField(
                name: command.resolvedLabel,
                combo: index.map { bindings[$0].combo } ?? "",
                conflict: conflict,
                preflight: preflight,
                onRecord: record,
                onClear: clear
            )
        }
        .keybindingRowStyle(
            inherited: isInherited,
            unavailable: command.unavailable?()
        )
        .id(command.lua)
    }

    private var index: Int? {
        bindings.firstIndex {
            $0.kind == .navigation && $0.lua == command.lua
        }
    }

    /// Override layer: bound-and-equal to the base row, or
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
        return ConflictText.tooltip(
            for: bindings[index],
            in: bindings,
            config: model.config
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
            // Steal live-applies too (via `record`); only the
            // recorder's own commit shows the caption.
            commit: { _ = record($0) }
        )
    }

    private func record(
        _ combo: String
    ) -> LiveApplyFeedback? {
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
            return model.liveApplyRecorded(
                layerName: layerName,
                bindingID: updated.id,
                combo: combo
            )
        }
        return nil
    }

    private func clear() {
        guard let index else { return }
        let id = bindings[index].id
        bindings.remove(at: index)
        // Live target: the removed hotkey unregisters now
        // (#123); no caption for a clear.
        _ = model.liveApplyRecorded(
            layerName: layerName,
            bindingID: id,
            combo: nil
        )
    }
}
