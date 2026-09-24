import Foundation
import KiwiDeskCore

/// Destructive action staged behind unsaved-changes confirmation (#515).
struct PendingDiscard: Identifiable {
    let id = UUID()
    /// Dialog title; nil takes the unsaved-changes one.
    var title: String? = nil
    let message: String
    let confirmLabel: String
    let perform: @MainActor () -> Void
    /// Return picks Cancel, so a reflex keypress never runs a
    /// destructive action that has no undo (#1619).
    var cancelIsDefault = false
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

    /// Parks a profile delete behind its confirm, clean or dirty:
    /// a profile has no undo (#1619). Staged edits fold into the
    /// same dialog — never a second one after it.
    func confirmingProfileDelete(
        _ name: String,
        perform action: @escaping @MainActor () -> Void
    ) {
        pendingDiscard = PendingDiscard(
            title: L(
                "profiles.delete.confirm.title",
                "Delete “%1$@”?",
                name
            ),
            message: isDirty
                ? L(
                    "profiles.delete.confirm.message_dirty",
                    "Its Spaces, layouts, rules and shortcuts will "
                        + "be deleted, and the edits you haven't "
                        + "saved will be discarded. You can't undo "
                        + "this."
                )
                : L(
                    "profiles.delete.confirm.message",
                    "Its Spaces, layouts, rules and shortcuts will "
                        + "be deleted. You can't undo this."
                ),
            confirmLabel: L("profiles.delete.confirm.button", "Delete"),
            perform: action,
            cancelIsDefault: true
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
