import Foundation
import KiwiDeskCore

/// A destructive action staged behind the unsaved-changes
/// confirmation (#515). Carries its own copy: the title and
/// Cancel are shared, but "what you are about to lose" reads
/// differently per path, so each caller supplies the message and
/// the confirm verb.
///
/// `Identifiable` only so the dialog's `presenting:` overload
/// has an id to key on; the *capture* is what makes replay safe,
/// and that comes from the overload itself, not this conformance.
struct PendingDiscard: Identifiable {
    let id = UUID()
    let message: String
    let confirmLabel: String
    let perform: @MainActor () -> Void
}

/// The discard gate's model half (#515). The view half — the
/// dialog and its modifier — is `DiscardConfirm.swift`.
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
    ///
    /// The action must genuinely discard. Parking a closure that
    /// leaves `isDirty` true makes the dialog a lie and prompts
    /// again on the next gated action (the #515 review caught
    /// exactly that on the raw-editor path).
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

    /// Confirms the parked action: clears the state FIRST, then
    /// runs it.
    ///
    /// The order is the point. Two gated actions flip
    /// `editingLua`, which re-mounts the view tree, so leaving
    /// the clear to the dialog's own dismissal path would race
    /// the teardown — and a surviving `pendingDiscard` would
    /// re-present the dialog for an action that already ran.
    /// Model-owned also makes the confirm path unit-testable,
    /// which a closure invoked only by SwiftUI is not.
    func confirmPendingDiscard() {
        guard let pending = pendingDiscard else { return }
        pendingDiscard = nil
        pending.perform()
    }

    /// Drops any parked action without running it — Cancel, and
    /// the guaranteed disarm net when the window closes.
    ///
    /// The window is retained (`isReleasedWhenClosed = false`)
    /// and merely ordered out, so without this a closure parked
    /// against a long-gone view could survive to the next
    /// `show()` and present a dialog about edits that no longer
    /// exist. Same reasoning as the recorder's disarm in
    /// `windowWillClose`. Idempotent.
    func cancelPendingDiscard() {
        pendingDiscard = nil
    }
}
