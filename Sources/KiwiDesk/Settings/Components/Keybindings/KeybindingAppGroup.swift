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
    /// The last pick that created nothing: WHICH app to ask
    /// about, and WHERE it was picked. Never the sentence, which
    /// `allBoundNotice` derives live (#1235).
    ///
    /// `row` is nil for the add row. It exists so the caption
    /// draws at the picker that refused rather than at the
    /// bottom of the group — a refusal raised from row 2 of
    /// twenty would otherwise paint below row 20, which for any
    /// scrolling list is silent for a sighted user (code review
    /// 2026-09-06). Keyed, so it is still ONE sentence and not
    /// gui.md's caption stamped under every child.
    @State var refusal: AppPickRefusal?

    /// The pending announcement, cancelled by the next pick so a
    /// post cannot land after its sentence stopped being true —
    /// the shape `SettingsFooter` uses for the same reason.
    @State var refusalAnnouncement: DispatchWorkItem?
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
        // A layer switch is a different set of bindings, so the
        // caption would be unprompted rather than wrong — the
        // derivation keeps it true either way.
        .onChange(of: layerName) { _, _ in
            recomputeOrder()
            clearRefusal()
        }
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
