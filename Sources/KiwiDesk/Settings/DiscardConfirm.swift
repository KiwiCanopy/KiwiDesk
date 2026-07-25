import KiwiDeskCore
import SwiftUI

/// A destructive action staged behind the unsaved-changes
/// confirmation (#515). Carries its own copy: the title and
/// Cancel are shared, but "what you are about to lose" reads
/// differently per path, so each caller supplies the message and
/// the confirm verb.
///
/// `Identifiable` so the dialog can present a *captured* value —
/// dismissal clears `SettingsModel.pendingDiscard`, and a
/// re-read after that would find nothing to act on.
struct PendingDiscard: Identifiable {
    let id = UUID()
    let message: String
    let confirmLabel: String
    let perform: () -> Void
}

extension SettingsModel {
    /// Runs `action` now when nothing is staged, or parks it
    /// behind the discard confirmation when it is.
    ///
    /// Every path that drops staged edits goes through here —
    /// the raw-Lua editor in both directions, profile
    /// Load/Delete/Rename, preset Apply, and the edit-target
    /// menu. They all end in `reload()`, which re-seeds from
    /// disk and clears `isDirty`, so without the gate the edits
    /// are gone with no prompt (and, on the Lua path, while the
    /// footer still reads "Unsaved changes").
    ///
    /// A caller whose action is a no-op must return before
    /// calling this — the gate has no way to tell an
    /// inconsequential action from a destructive one, and would
    /// pop a pointless dialog.
    func discardingEdits(
        message: String,
        confirmLabel: String,
        perform action: @escaping () -> Void
    ) {
        guard isDirty else { return action() }
        pendingDiscard = PendingDiscard(
            message: message,
            confirmLabel: confirmLabel,
            perform: action
        )
    }
}

/// Hosts the one discard dialog for the whole dashboard. Applied
/// in `SettingsView.chrome`, which wraps *both* modes — the raw
/// Lua editor needs it as much as the structured shell does.
struct DiscardConfirmation: ViewModifier {
    @ObservedObject var model: SettingsModel

    func body(content: Content) -> some View {
        content.confirmationDialog(
            L("discard.title", "Discard unsaved changes?"),
            isPresented: Binding(
                get: { model.pendingDiscard != nil },
                set: { shown in
                    if !shown { model.pendingDiscard = nil }
                }
            ),
            titleVisibility: .visible,
            presenting: model.pendingDiscard
        ) { pending in
            Button(
                pending.confirmLabel,
                role: .destructive,
                action: pending.perform
            )
            Button(
                L("discard.cancel", "Cancel"),
                role: .cancel
            ) {}
        } message: { pending in
            Text(pending.message)
        }
    }
}

extension View {
    func discardConfirmation(
        model: SettingsModel
    ) -> some View {
        modifier(DiscardConfirmation(model: model))
    }
}
