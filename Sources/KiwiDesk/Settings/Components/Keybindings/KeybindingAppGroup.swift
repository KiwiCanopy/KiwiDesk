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
    /// Read by the row in `+Row` (dimming) and by the recorders
    /// there (the live-apply seam), so neither is `private`.
    @Environment(\.keybindingOverrideBase)
    var overrideBase
    @Environment(\.keybindingLayerName)
    var layerName
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
            if orderedAppIDs.isEmpty {
                // What holds instead of the empty list (#678
                // Phase 4 pass 9, turn 18): what a binding here
                // changes is what the emptiness leaves the reader
                // wondering about. Worded FROM
                // `shortcuts.app_behavior.help`, authoritative
                // for the Open or Focus default a new row gets —
                // crossing SPACES is the distinguishing
                // behaviour, "brings it forward" is plain
                // activation, and the two would take different
                // verbs in ten languages (l10n audit,
                // 2026-08-11).
                Text(
                    L(
                        "shortcuts.apps.empty",
                        "No app has a key of its own yet. Add one "
                            + "and its key brings that app's "
                            + "window to the space you're on, or "
                            + "launches the app if it isn't "
                            + "running."
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
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
        .onChange(of: layerName) { _, _ in recomputeOrder() }
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

    /// Deleting a row must unregister its hotkey, exactly as the
    /// recorder's `onClear` in `+Row` does (#517). Without this the row
    /// vanishes while its shortcut keeps firing until Save or
    /// Revert — `liveApplyRecorded` rebuilds the running table
    /// from its own session copy, which never saw the removal.
    /// No-op off the live target, where nothing is registered.
    /// Called by the row's trash button in `+Row`, so not
    /// `private`.
    func remove(_ id: UUID) {
        bindings.removeAll { $0.id == id }
        _ = model.liveApplyRecorded(
            layerName: layerName,
            bindingID: id,
            combo: nil
        )
    }
}
