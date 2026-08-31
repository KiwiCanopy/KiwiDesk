import Foundation
import KiwiDeskCore

/// Destructive action staged behind unsaved-changes confirmation (#515).
struct PendingDiscard: Identifiable {
    let id = UUID()
    let message: String
    let confirmLabel: String
    let perform: @MainActor () -> Void
}

/// Discard confirmation gating logic on `SettingsModel`
/// (#515, `DiscardConfirm.swift`).
extension SettingsModel {
    /// Executes action now when nothing is staged, or parks it
    /// behind the discard confirmation (#515). A caller whose
    /// action is a no-op must return before calling — the gate
    /// cannot tell it from a destructive one. The action must
    /// genuinely discard: parking a closure that leaves `isDirty`
    /// true makes the dialog a lie and re-prompts on the next
    /// gated action (the #515 review caught exactly that).
    func discardingEdits(
        message: String,
        confirmLabel: String,
        perform action: @escaping @MainActor () -> Void
    ) {
        guard isDirty else { return action() }
        pendingDiscard = PendingDiscard(
            message: message,
            confirmLabel: confirmLabel,
            perform: action
        )
    }

    /// Confirms a parked action: clears FIRST (gated actions can
    /// re-mount the tree, and a surviving `pendingDiscard` would
    /// re-present for an action that already ran), and takes the
    /// VALUE rather than re-reading it — SwiftUI does not
    /// contract whether dismissal-clear runs before the button
    /// action, and a lost race would make Discard a silent no-op
    /// (`SpacesSection+Customize` uses the capture for the same
    /// reason).
    func confirmPendingDiscard(_ pending: PendingDiscard) {
        pendingDiscard = nil
        pending.perform()
    }

    /// Cancels a parked action — Cancel, and the disarm net on
    /// window close: the window is retained
    /// (`isReleasedWhenClosed = false`), so a parked closure could
    /// otherwise survive to the next `show()` and present a dialog
    /// about edits that no longer exist (`windowWillClose`).
    func cancelPendingDiscard() {
        pendingDiscard = nil
    }
}
