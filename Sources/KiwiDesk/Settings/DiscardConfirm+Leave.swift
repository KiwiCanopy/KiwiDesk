import SwiftUI

/// The close / quit question's three verbs (#2049 ruling): Save
/// on Return, Discard on ⌘D, Cancel on Escape — and, where saving
/// is blocked, Discard and Cancel with Return on Cancel.
extension DiscardConfirmation {
    @ViewBuilder
    func leaveActions(_ pending: PendingDiscard) -> some View {
        if let save = pending.saveLabel {
            Button(save) { model.saveAndLeave(pending) }
                .keyboardShortcut(.defaultAction)
        }
        Button(pending.confirmLabel, role: .destructive) {
            model.confirmPendingDiscard(pending)
        }
        .keyboardShortcut("d")
        Button(pending.cancelLabel, role: .cancel) {
            model.cancelPendingDiscard()
        }
        .keyboardShortcut(
            pending.saveLabel == nil ? .defaultAction : nil
        )
    }
}
