import KiwiDeskCore
import SwiftUI

/// Single navigation shortcut row with label and recorder field
/// (#34, #68 §3.6.2).
struct NavRow: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let command: NavCommand
    @Environment(\.keybindingLayerName)
    private var layerName
    @Environment(\.disabledSystemShortcuts)
    private var disabledSystemShortcuts
    /// A clear of a shortcut other profiles share asks where it
    /// goes, as the trash does (#1393).
    @State private var confirmingClear = false

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
            if let index {
                KeyReachColumn(
                    model: model,
                    layer: layerName,
                    binding: bindings[index]
                )
            }
            KeyRecorderField(
                name: command.resolvedLabel,
                combo: index.map { bindings[$0].combo } ?? "",
                reading: reading,
                preflight: preflight,
                onRecord: record,
                onClear: clear
            )
        }
        .keybindingRowStyle(unavailable: command.unavailable?())
        .confirmationDialog(
            L(
                "shortcuts.clear_shared.title",
                "Other profiles use this shortcut too."
            ),
            isPresented: $confirmingClear
        ) {
            if let editing = sharedFrom {
                Button(
                    L("app_rules.remove.here", "Remove from %1$@", editing)
                ) { clear(.here) }
            }
            Button(
                L("app_rules.remove.everywhere", "Remove from every profile")
            ) { clear(.everywhere) }
        }
        .id(command.lua)
    }

    private var index: Int? {
        bindings.firstIndex {
            $0.kind == .navigation && $0.lua == command.lua
        }
    }

    private var reading: ConflictReading? {
        guard let index else { return nil }
        return ConflictText.reading(
            for: bindings[index],
            in: bindings,
            config: model.config,
            disabled: disabledSystemShortcuts
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

    /// The edited profile, where another profile shares this row.
    private var sharedFrom: String? {
        guard model.offersReachColumn, let index,
            let reading = model.keyReach(
                RuleReachTable<String>.keyID(
                    layer: layerName,
                    lua: bindings[index].lua
                )
            ),
            reading.users.count > 1
        else { return nil }
        return reading.editing
    }

    private func clear() {
        if sharedFrom != nil {
            confirmingClear = true
        } else {
            clear(.everywhere)
        }
    }

    private func clear(_ removal: RuleRemoval) {
        guard let index else { return }
        model.recordRemoval(
            .key,
            RuleReachTable<String>.keyID(
                layer: layerName,
                lua: bindings[index].lua
            ),
            removal
        )
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
