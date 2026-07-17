import AppKit
import KiwiDeskCore
import SwiftUI

/// Section 2 — Open Applications: launch hotkeys. Each row picks
/// an installed app (or any bundle via "Other…") and records a
/// combo. The Lua action pulls the app into the current space,
/// launching it if needed.
struct ApplicationsSection: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    @Environment(\.keybindingOverrideBase)
    private var overrideBase
    @Environment(\.keybindingModeName)
    private var modeName
    /// The app chosen in the add-row but not yet committed — the
    /// row only enters the list once an app is picked, so no
    /// app-less placeholder can exist (matches App Rules).
    @State private var newApp: KeybindingCatalog.InstalledApp?
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
            L(
                "shortcuts.section.open_applications",
                "Open Applications"
            )
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

    /// Pick an app, then commit it — mirroring App Rules, so a
    /// new binding always lands with an app identity (its
    /// shortcut is recorded afterward in the row).
    private var addRow: some View {
        HStack {
            AppPickerButton(
                placeholder: L(
                    "shortcuts.choose_app",
                    "Choose app…"
                ),
                selection: newApp?.name,
                onPick: { newApp = $0 },
                escapeLabel: L(
                    "shortcuts.other_ellipsis",
                    "Other…"
                ),
                onEscape: {
                    if let app = pickBundleFromPanel() {
                        newApp = app
                    }
                }
            )
            // Hug the content, like the per-row picker.
            .fixedSize()
            Button {
                addApplication()
            } label: {
                Label(
                    L(
                        "shortcuts.add_application",
                        "Add application"
                    ),
                    systemImage: "plus"
                )
            }
            .buttonStyle(.bordered)
            .disabled(newApp == nil)
        }
    }

    private func addApplication() {
        guard let app = newApp else { return }
        var binding = KeyBinding(kind: .application)
        binding.label = app.name
        binding.lua = KeybindingCatalog.appCommand(app.bundleID)
        bindings.append(binding)
        newApp = nil
    }

    private func row(
        _ binding: Binding<KeyBinding>
    ) -> some View {
        HStack {
            appMenu(binding)
            behaviorMenu(binding)
            Spacer()
            KeyRecorderField(
                combo: binding.wrappedValue.combo,
                conflict: KeybindingConflicts.text(
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
            }
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
        binding.wrappedValue.label = app.name
        binding.wrappedValue.lua = KeybindingCatalog.appCommand(
            app.bundleID
        )
    }

    /// The "Other…" escape hatch: pick any app bundle by file,
    /// returning it as an `InstalledApp` (nil on cancel). Shared
    /// by the per-row re-pick and the add-row.
    private func pickBundleFromPanel()
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

    private func remove(_ id: UUID) {
        bindings.removeAll { $0.id == id }
    }
}
