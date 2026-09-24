import Foundation
import KiwiDeskCore

/// Destructive action staged behind the one dashboard dialog
/// (#515): a discard of staged edits, or a profile delete that
/// asks even when clean (#1619).
struct PendingDiscard: Identifiable {
    /// What the dialog confirms. The kind decides the title, the
    /// Cancel wording and which button Return picks, so no
    /// caller can set one and forget the others.
    enum Kind: Equatable {
        case discard
        case deleteProfile(name: String)
    }

    let id = UUID()
    var kind = Kind.discard
    let message: String
    let confirmLabel: String
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
        }
    }

    /// `discard.cancel` reads "Keep editing" in several catalogs,
    /// which a clean delete has nothing to keep.
    @MainActor var cancelLabel: String {
        switch kind {
        case .discard: return L("discard.cancel", "Cancel")
        case .deleteProfile:
            return L("profiles.delete.confirm.cancel", "Cancel")
        }
    }

    /// Return picks Cancel on a delete with no undo, so a reflex
    /// keypress deletes nothing (#1619).
    var cancelIsDefault: Bool { kind != .discard }
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
    /// same dialog — never a second one after it. A `broken`
    /// profile's file may not be readable, so its message names
    /// only the file.
    func confirmingProfileDelete(
        _ name: String,
        broken: Bool = false,
        perform action: @escaping @MainActor () -> Void
    ) {
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
        pendingDiscard = nil
    }
}
