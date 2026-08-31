import KiwiDeskCore
import SwiftUI

/// Application shortcut row component (`KeybindingAppGroup`, `KeyBinding`).
extension ApplicationsGroup {
    func row(
        _ binding: Binding<KeyBinding>
    ) -> some View {
        HStack {
            HStack(spacing: 6) {
                appMenu(binding)
                behaviorMenu(binding)
            }
            Spacer()
            KeyRecorderField(
                name: binding.wrappedValue.label.isEmpty
                    ? L("shortcuts.choose_app", "Choose app…")
                    : binding.wrappedValue.label,
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

    private func appMenu(
        _ binding: Binding<KeyBinding>
    ) -> some View {
        AppPickerButton(
            placeholder: L(
                "shortcuts.choose_app",
                "Choose app…"
            ),
            selection: binding.wrappedValue.label.isEmpty
                ? nil
                : binding.wrappedValue.label,
            onPick: { assign(binding, app: $0) },
            escapeLabel: L("shortcuts.other_ellipsis", "Other…"),
            onEscape: {
                if let app = pickBundleFromPanel() {
                    assign(binding, app: app)
                }
            },
            exclude: fullyBoundBundleIDs(
                excluding: binding.wrappedValue.id
            )
        )
        .fixedSize()
    }

    private func assign(
        _ binding: Binding<KeyBinding>,
        app: KeybindingCatalog.InstalledApp
    ) {
        let id = binding.wrappedValue.id
        let taken = KeybindingCatalog.takenBehaviors(
            for: app.bundleID,
            in: bindings,
            excluding: id
        )
        guard taken.count < AppLaunchBehavior.allCases.count else {
            return
        }
        let current =
            KeybindingCatalog.appLaunchBehavior(
                from: binding.wrappedValue.lua
            ) ?? .openOrFocus
        let behavior = KeybindingCatalog.behaviorForAssignment(
            to: app.bundleID,
            preferred: current,
            in: bindings,
            excluding: id
        )
        binding.wrappedValue.label = app.name
        binding.wrappedValue.lua = KeybindingCatalog.appCommand(
            app.bundleID,
            behavior: behavior
        )
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

    /// Records shortcut combo lookup by ID (`UUID`).
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
