import AppKit
import KiwiDeskCore
import SwiftUI

/// Launch hotkeys group for applications (#334).
struct ApplicationsGroup: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    @Environment(\.keybindingOverrideBase)
    var overrideBase
    @Environment(\.disabledSystemShortcuts)
    var disabledSystemShortcuts
    @Environment(\.keybindingLayerName)
    var layerName
    @State var newApp: KeybindingCatalog.InstalledApp?
    /// Alphabetical display order snapshotted on section entry
    /// (#333). NOT recomputed on `bindings` mutation: the row's
    /// control is a `KeyRecorderField` capture, and a live re-sort
    /// could yank a row from under the cursor mid-record. A new
    /// row stays at the bottom this session.
    @State private var displayOrder: [UUID] = []

    var body: some View {
        SettingsSection(
            SettingsCatalog.shortcuts.openApplications
        ) {
            if orderedAppIDs.isEmpty {
                // Worded FROM `shortcuts.app_behavior.help` (#678
                // Phase 4 pass 9): crossing SPACES is the
                // distinguishing behaviour, and the two verbs
                // differ in ten languages (l10n audit 2026-08-11).
                Text(
                    L(
                        "shortcuts.apps.empty",
                        "No app has a key of its own yet. Add one "
                            + "and its key brings that app's "
                            + "window to the Space you're on, or "
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
        // The section view is reused across modes (no per-mode
        // `.id`), so `onAppear` fires once — re-snapshot on mode
        // change or later modes render in raw array order.
        .onChange(of: layerName) { _, _ in recomputeOrder() }
    }

    /// Application binding IDs in snapshot alpha order with new rows
    /// appended (#333).
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

    /// Presents open panel to select custom application bundle.
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

    /// Removes binding and unregisters active hotkey
    /// (#517, `liveApplyRecorded`).
    func remove(_ id: UUID) {
        bindings.removeAll { $0.id == id }
        _ = model.liveApplyRecorded(
            layerName: layerName,
            bindingID: id,
            combo: nil
        )
    }
}
