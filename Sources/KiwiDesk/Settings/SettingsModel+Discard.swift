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
    /// Executes action immediately if clean, or queues pending discard
    /// (`reload()`, #515).
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

    /// Confirms and executes pending discard action
    /// (`SpacesSection+Customize`).
    func confirmPendingDiscard(_ pending: PendingDiscard) {
        pendingDiscard = nil
        pending.perform()
    }

    /// Cancels pending discard action
    /// (`isReleasedWhenClosed = false`, `windowWillClose`).
    func cancelPendingDiscard() {
        pendingDiscard = nil
    }
}
