import KiwiDeskCore
import SwiftUI

/// One bound application's row, and the two paths that write a
/// combo into it. Split from `KeybindingAppGroup` at the §2.1
/// ceiling (l10n round, 2026-08-11), on the same seam as
/// `+AddRow` and `+Behavior`: the group owns the LIST — its
/// order, its lookups, its add-row — and this owns what one row
/// draws and what recording into it does.
extension ApplicationsGroup {
    func row(
        _ binding: Binding<KeyBinding>
    ) -> some View {
        HStack {
            // Tighter than the row's ambient spacing so "app + how
            // to open it" reads as one unit (ui-designer, #334).
            HStack(spacing: 6) {
                appMenu(binding)
                behaviorMenu(binding)
            }
            Spacer()
            KeyRecorderField(
                combo: binding.wrappedValue.combo,
                conflict: ConflictText.tooltip(
                    for: binding.wrappedValue,
                    in: bindings,
                    config: model.config
                ),
                preflight: { combo in
                    RecorderPreflight.rejection(
                        combo: combo,
                        excluding: {
                            [id = binding.wrappedValue.id] in
                            $0.id == id
                        },
                        bindings: $bindings,
                        // Id-based (#68 review M2): Steal
                        // mutates the array before this runs.
                        commit: {
                            _ = record(
                                $0,
                                id: binding.wrappedValue.id
                            )
                        }
                    )
                },
                onRecord: { record($0, into: binding) },
                onClear: {
                    let id = binding.wrappedValue.id
                    binding.wrappedValue.combo = ""
                    // Live target: unregister now (#123).
                    _ = model.liveApplyRecorded(
                        layerName: layerName,
                        bindingID: id,
                        combo: nil
                    )
                }
            )
            Button {
                remove(binding.wrappedValue.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .iconButtonAffordance(
                L(
                    "shortcuts.remove_binding",
                    "Remove shortcut"
                )
            )
        }
        .keybindingRowStyle(
            inherited: binding.wrappedValue.isInherited(
                from: overrideBase
            )
        )
        .id(binding.wrappedValue.id.uuidString)
    }

    private func record(
        _ combo: String,
        into binding: Binding<KeyBinding>
    ) -> LiveApplyFeedback? {
        binding.wrappedValue.combo = combo
        let id = binding.wrappedValue.id
        if let index = bindings.firstIndex(
            where: { $0.id == id }
        ) {
            model.noteRecordedCombo(
                bindings[index],
                in: bindings
            )
        }
        return model.liveApplyRecorded(
            layerName: layerName,
            bindingID: id,
            combo: combo
        )
    }

    /// Looks the row up by id at write time — safe after any
    /// structural mutation of the bindings array.
    @discardableResult
    private func record(
        _ combo: String,
        id: UUID
    ) -> LiveApplyFeedback? {
        guard
            let index = bindings.firstIndex(where: {
                $0.id == id
            })
        else { return nil }
        bindings[index].combo = combo
        model.noteRecordedCombo(
            bindings[index],
            in: bindings
        )
        return model.liveApplyRecorded(
            layerName: layerName,
            bindingID: id,
            combo: combo
        )
    }
}
