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
    @Environment(\.keybindingReservesTrashSlot)
    private var reservesTrashSlot
    /// A clear of a shortcut other profiles share asks where it
    /// goes, as the trash does (#1393).
    @State private var confirmingClear = false

    var body: some View {
        HStack {
            // Icon slot reserved unconditionally (#264); the
            // panel's glyph (#2670).
            Color.clear
                .frame(width: SettingsMetrics.shortcutIconSlot)
                .overlay {
                    if command.lua == KeybindingCatalog.pocket.lua {
                        // The mark itself, as the panel draws it.
                        Image(
                            nsImage: PocketMark.mark.image(size: 16, hex: "")
                        )
                        .frame(width: 16, height: 16)
                        .accessibilityHidden(true)
                    } else if let glyph = ShortcutsReferenceBuilder.icon(
                        for: command
                    ) {
                        IconGlyphLabel(icon: glyph)
                    }
                }
            Text(command.resolvedLabel)
            if let kind = command.liveOnly {
                LiveOnlySpaceChip(kind: kind)
            }
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
            if reservesTrashSlot {
                AppRuleDeleteButton.slot
            }
        }
        .keybindingRowStyle(unavailable: command.unavailable?())
        .confirmationDialog(
            L(
                "shortcuts.clear_shared.title",
                "Other profiles use this shortcut too."
            ),
            isPresented: $confirmingClear
        ) {
            if let reading = sharedFrom {
                Button(RuleReachWords.removeHere(reading)) { clear(.here) }
                Button(RuleReachWords.removeEverywhere(reading)) {
                    clear(.everywhere)
                }
            }
        }
        .id(command.lua)
    }

    private var index: Int? {
        bindings.firstIndex {
            $0.kind == .navigation && command.runs($0.lua)
        }
    }

    private var reading: ConflictReading? {
        guard let index else { return nil }
        return ConflictText.reading(
            for: bindings[index],
            in: bindings,
            config: model.config,
            disabled: disabledSystemShortcuts,
            sides: model.appWide.modifierSides
        )
    }

    private func preflight(
        _ combo: String
    ) -> RecorderRejection? {
        RecorderPreflight.rejection(
            combo: combo,
            excluding: { [command] in
                $0.kind == .navigation && command.runs($0.lua)
            },
            bindings: $bindings,
            config: model.config,
            commit: { record($0) }
        )
    }

    private func record(
        _ combo: String
    ) {
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
            $0.kind == .navigation && command.runs($0.lua)
        }) {
            model.noteRecordedCombo(updated, in: bindings)
        }
    }

    /// The edited profile, where another profile shares this row.
    private var sharedFrom: RuleReachReading? {
        guard model.offersReachColumn, let index,
            let reading = model.keyReach(
                RuleReachTable<String>.keyID(
                    layer: layerName,
                    lua: bindings[index].lua
                )
            ),
            reading.users.count > 1
        else { return nil }
        return reading
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
        bindings.remove(at: index)
    }
}
