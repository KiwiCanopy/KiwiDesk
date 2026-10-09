import Foundation
import KiwiDeskCore

/// Destructive action staged behind the one dashboard dialog
/// (#515): a discard of staged edits, a profile delete that asks
/// even when clean (#1619), or a close or quit over unsaved edits
/// (#2049).
struct PendingDiscard: Identifiable {
    /// What the dialog confirms. The kind decides the title, the
    /// Cancel wording and which button Return picks, so no
    /// caller can set one and forget the others.
    enum Kind: Equatable {
        case discard
        case deleteProfile(name: String)
        /// Save / Discard / Cancel before a close or quit (#2049).
        case leave(DraftLeave.Intent)
    }

    let id = UUID()
    var kind = Kind.discard
    let message: String
    let confirmLabel: String
    /// A leave's Save verb; nil where saving is blocked.
    var saveLabel: String?
    let perform: @MainActor () -> Void

    @MainActor var title: String {
        switch kind {
        case .discard:
            return L("discard.title", "Discard unsaved changes?")
        case .deleteProfile(let name):
            return L(
                "profiles.delete.confirm.title",
                "Delete “%1$@”?",
                name
            )
        case .leave(.close):
            return L(
                "discard.leave.close.title",
                "Save your changes before closing Settings?"
            )
        case .leave(.quit):
            return L(
                "discard.leave.quit.title",
                "Save your changes before quitting KiwiDesk?"
            )
        }
    }

    /// `discard.cancel` reads "Keep editing" in several catalogs,
    /// which a clean delete has nothing to keep.
    @MainActor var cancelLabel: String {
        switch kind {
        case .discard, .leave: return L("discard.cancel", "Cancel")
        case .deleteProfile:
            return L("profiles.delete.confirm.cancel", "Cancel")
        }
    }

    /// Return picks Cancel on a delete with no undo, so a reflex
    /// keypress deletes nothing (#1619). A leave picks Save, or
    /// Cancel where Save is blocked (`DiscardConfirmation`).
    var cancelIsDefault: Bool {
        if case .deleteProfile = kind { return true }
        return false
    }

    var isLeave: Bool {
        if case .leave = kind { return true }
        return false
    }
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
    /// same dialog — never a second one after it. A broken
    /// profile's file may not be readable, so its message names
    /// only the file — read off `brokenProfiles`, never handed in.
    func confirmingProfileDelete(
        _ name: String,
        perform action: @escaping @MainActor () -> Void
    ) {
        let broken = brokenProfiles.contains { $0.name == name }
        pendingDiscard = PendingDiscard(
            kind: .deleteProfile(name: name),
            message: deleteMessage(broken: broken),
            confirmLabel: L("profiles.delete.confirm.button", "Delete"),
            perform: action
        )
    }

    private func deleteMessage(broken: Bool) -> String {
        switch (broken, isDirty) {
        case (false, false):
            return L(
                "profiles.delete.confirm.message",
                "Its Spaces, layouts, rules and shortcuts will "
                    + "be deleted. You can't undo this."
            )
        case (false, true):
            return L(
                "profiles.delete.confirm.message_dirty",
                "Its Spaces, layouts, rules and shortcuts will "
                    + "be deleted, and the edits you haven't "
                    + "saved will be discarded. You can't undo "
                    + "this."
            )
        case (true, false):
            return L(
                "profiles.delete.confirm.message_broken",
                "This removes the profile file. You can't undo "
                    + "this."
            )
        case (true, true):
            return L(
                "profiles.delete.confirm.message_broken_dirty",
                "This removes the profile file, and the edits you "
                    + "haven't saved will be discarded. You can't "
                    + "undo this."
            )
        }
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
        let leaving = pendingDiscard?.isLeave == true
        pendingDiscard = nil
        if leaving { finishLeave(proceeding: false) }
    }
}
