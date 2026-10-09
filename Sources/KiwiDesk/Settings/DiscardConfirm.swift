import KiwiDeskCore
import SwiftUI

/// Hosts the one discard dialog for the whole dashboard (#515).
/// Applied in `SettingsView.body` ABOVE the `editingLua`
/// branch: two of the gated actions flip that flag, so a host
/// inside either arm would be torn down by its own confirm
/// button.
struct DiscardConfirmation: ViewModifier {
    @ObservedObject var model: SettingsModel

    func body(content: Content) -> some View {
        content.confirmationDialog(
            // Nothing presents without a pending value.
            model.pendingDiscard?.title ?? "",
            isPresented: Binding(
                get: { model.pendingDiscard != nil },
                set: { shown in
                    // Dismissal only. Confirm clears the state
                    // itself, before running, so this never has
                    // to win a race against a view swap.
                    if !shown { model.discardDialogDismissed() }
                }
            ),
            titleVisibility: .visible,
            presenting: model.pendingDiscard
        ) { pending in
            if pending.isLeave {
                leaveActions(pending)
            } else {
                gateActions(pending)
            }
        } message: { pending in
            Text(pending.message)
        }
    }

    @ViewBuilder
    private func gateActions(_ pending: PendingDiscard) -> some View {
        // Hand over the presented value, never a re-read:
        // the dismissal setter above clears the same state,
        // and SwiftUI does not contract which runs first.
        Button(pending.confirmLabel, role: .destructive) {
            model.confirmPendingDiscard(pending)
        }
        Button(pending.cancelLabel, role: .cancel) {}
            .keyboardShortcut(
                pending.cancelIsDefault ? .defaultAction : nil
            )
    }
}

extension View {
    func discardConfirmation(
        model: SettingsModel
    ) -> some View {
        modifier(DiscardConfirmation(model: model))
    }
}
