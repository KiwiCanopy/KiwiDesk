import KiwiDeskCore
import SwiftUI

/// Hosts the one discard dialog for the whole dashboard (#515).
/// Applied in `SettingsView.body` **above** the `editingLua`
/// branch: two of the gated actions flip that flag, so a host
/// inside either arm would be torn down by its own confirm
/// button. The model half — `PendingDiscard` and the gate — is
/// `SettingsModel+Discard.swift`.
struct DiscardConfirmation: ViewModifier {
    @ObservedObject var model: SettingsModel

    func body(content: Content) -> some View {
        content.confirmationDialog(
            L("discard.title", "Discard unsaved changes?"),
            isPresented: Binding(
                get: { model.pendingDiscard != nil },
                set: { shown in
                    // Dismissal only. Confirm clears the state
                    // itself, before running, so this never has
                    // to win a race against a view swap.
                    if !shown { model.cancelPendingDiscard() }
                }
            ),
            titleVisibility: .visible,
            presenting: model.pendingDiscard
        ) { pending in
            Button(pending.confirmLabel, role: .destructive) {
                model.confirmPendingDiscard()
            }
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
