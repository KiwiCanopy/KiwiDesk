import KiwiDeskCore
import SwiftUI

/// One bound application's row: what it draws, what picking an
/// app on it does, and the two paths that write a combo into it.
/// Split from `KeybindingAppGroup` at the §2.1 ceiling (l10n
/// round, 2026-08-11), on the same seam as `+AddRow` and
/// `+Behavior`: the group owns the LIST — its order, its lookups,
/// its add-row — and this owns one row of it.
///
/// Everything a row alone needs came WITH it and stayed
/// `private`. What the group still holds is what the list also
/// uses: `pickBundleFromPanel` (the add-row's "Other…" escape
/// too) and `remove` / the two environment values, which the
/// list's own wiring reads.
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
            // Drop apps every behavior of which is already bound on
            // *other* rows — re-picking to one could only duplicate
            // (this row excluded, so its own app stays pickable).
            exclude: fullyBoundBundleIDs(
                excluding: binding.wrappedValue.id
            )
        )
        // Hug the content: the row's `Spacer()` pins the recorder
        // to the trailing edge, so the picker's width doesn't gate
        // recorder alignment — no fixed column needed.
        .fixedSize()
    }

    private func assign(
        _ binding: Binding<KeyBinding>,
        app: KeybindingCatalog.InstalledApp
    ) {
        let id = binding.wrappedValue.id
        // Decline a re-pick onto an app every behavior of which is
        // already bound on *other* rows — any assignment would
        // duplicate. The picker hides these, but the "Other…"
        // escape bypasses that list, so guard at this choke point
        // (mirrors the add-row's `addApplication` bail — #334
        // review).
        let taken = KeybindingCatalog.takenBehaviors(
            for: app.bundleID,
            in: bindings,
            excluding: id
        )
        guard taken.count < AppLaunchBehavior.allCases.count else {
            return
        }
        // Keep the row's launch behavior across a re-pick when it's
        // still free for the new app, else take the first free one —
        // so a re-pick can't silently collide with another row's
        // app+behavior.
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
