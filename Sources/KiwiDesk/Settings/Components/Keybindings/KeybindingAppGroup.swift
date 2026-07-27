import AppKit
import KiwiDeskCore
import SwiftUI

/// Section 2 — Open applications: launch hotkeys. Each row picks
/// an installed app (or any bundle via "Other…"), a launch
/// behavior (Open or Focus / Open New, #334), and a combo. The
/// default action pulls the app into the current space, launching
/// it if needed.
struct ApplicationsGroup: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    @Environment(\.keybindingOverrideBase)
    private var overrideBase
    @Environment(\.keybindingModeName)
    private var modeName
    /// The app chosen in the add-row but not yet committed — the
    /// row only enters the list once an app is picked, so no
    /// app-less placeholder can exist (matches App Rules). Read by
    /// the add-row in `+AddRow`, so not `private`.
    @State var newApp: KeybindingCatalog.InstalledApp?
    /// Alphabetical display order snapshotted on section entry and
    /// mode change (#333). NOT recomputed on `bindings` mutation:
    /// the row's control is a `KeyRecorderField` capture, so a live
    /// re-sort could yank a row out from under the cursor
    /// mid-record. A committed *new* row stays at the bottom this
    /// session and takes its alpha slot next entry; re-picking an
    /// app keeps the row's id, so it holds its existing slot.
    @State private var displayOrder: [UUID] = []

    var body: some View {
        SettingsSection(
            SettingsCatalog.shortcuts.openApplications
        ) {
            ForEach(orderedAppIDs, id: \.self) { id in
                if let binding = bindingFor(id) {
                    row(binding)
                }
            }
            addRow
        }
        .onAppear(perform: recomputeOrder)
        // The section view is reused across keybinding modes (no
        // per-mode `.id`), so `onAppear` fires once — re-snapshot
        // when the mode changes or later modes would render in raw
        // array order. Recording is invalidated on mode switch, so
        // re-sorting here can't yank an in-flight recorder.
        .onChange(of: modeName) { _, _ in recomputeOrder() }
    }

    /// Application-binding ids in the snapshot's alpha order, with
    /// any added since (absent from the snapshot) kept in array
    /// order at the bottom for this session (#333).
    private var orderedAppIDs: [UUID] {
        let appIDs =
            bindings
            .filter { $0.kind == .application }
            .map(\.id)
        let present = Set(appIDs)
        let known = displayOrder.filter(present.contains)
        let knownSet = Set(known)
        return known + appIDs.filter { !knownSet.contains($0) }
    }

    private func recomputeOrder() {
        displayOrder =
            bindings
            .filter { $0.kind == .application }
            .sorted { lhs, rhs in
                let order = lhs.label
                    .localizedCaseInsensitiveCompare(rhs.label)
                if order == .orderedSame {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return order == .orderedAscending
            }
            .map(\.id)
    }

    /// A stable, id-keyed binding into `bindings` — resolved at
    /// access time so it survives any structural mutation of the
    /// array (add / remove / Steal reorder).
    private func bindingFor(_ id: UUID) -> Binding<KeyBinding>? {
        guard bindings.contains(where: { $0.id == id }) else {
            return nil
        }
        return Binding(
            get: {
                bindings.first { $0.id == id }
                    ?? KeyBinding(kind: .application)
            },
            set: { newValue in
                if let index = bindings.firstIndex(where: {
                    $0.id == id
                }) {
                    bindings[index] = newValue
                }
            }
        )
    }

    private func row(
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
                    in: bindings
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
                        modeName: modeName,
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
            modeName: modeName,
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
            modeName: modeName,
            bindingID: id,
            combo: combo
        )
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

    /// The "Other…" escape hatch: pick any app bundle by file,
    /// returning it as an `InstalledApp` (nil on cancel). Shared
    /// by the per-row re-pick and the add-row (in `+AddRow`).
    func pickBundleFromPanel()
        -> KeybindingCatalog.InstalledApp?
    {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        panel.directoryURL = URL(
            fileURLWithPath: "/Applications"
        )
        guard panel.runModal() == .OK, let url = panel.url,
            let bundleID = Bundle(url: url)?
                .bundleIdentifier?.lowercased()
        else { return nil }
        return .init(
            bundleID: bundleID,
            name: KeybindingCatalog.displayName(
                forBundleID: bundleID
            )
        )
    }

    /// Deleting a row must unregister its hotkey, exactly as
    /// `onClear` does above (#517). Without this the row
    /// vanishes while its shortcut keeps firing until Save or
    /// Revert — `liveApplyRecorded` rebuilds the running table
    /// from its own session copy, which never saw the removal.
    /// No-op off the live target, where nothing is registered.
    private func remove(_ id: UUID) {
        bindings.removeAll { $0.id == id }
        _ = model.liveApplyRecorded(
            modeName: modeName,
            bindingID: id,
            combo: nil
        )
    }
}
