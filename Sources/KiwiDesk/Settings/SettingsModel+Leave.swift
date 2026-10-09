import Foundation
import KiwiDeskCore

/// A close or quit held by the unsaved-edits question (#2049):
/// what runs once it is answered.
struct DraftLeave {
    enum Intent: Equatable {
        case close
        case quit
    }

    let proceed: @MainActor () -> Void
    let cancel: @MainActor () -> Void
}

/// Save / Discard / Cancel before the Settings window closes or
/// KiwiDesk quits with unsaved edits (#2049 ruling), through the
/// one discard gate (`PendingDiscard`, one pending slot).
extension SettingsModel {
    /// Runs `proceed` at once on a clean draft; otherwise asks,
    /// replacing (and cancelling) any leave already waiting.
    func leavingDraft(
        _ intent: DraftLeave.Intent,
        proceed: @escaping @MainActor () -> Void,
        cancel: @escaping @MainActor () -> Void
    ) {
        guard isDirty else { return proceed() }
        finishLeave(proceeding: false)
        draftLeave = DraftLeave(proceed: proceed, cancel: cancel)
        let canSave = leaveCanSave
        let lost = L(
            "discard.leave.message",
            "If you don't save, your changes will be lost."
        )
        pendingDiscard = PendingDiscard(
            kind: .leave(intent),
            message: canSave ? lost : (leaveSaveBlockedReason ?? lost),
            confirmLabel: L("discard.leave.confirm", "Discard"),
            saveLabel: canSave ? leaveSaveLabel : nil,
            perform: { [weak self] in
                self?.revert()
                self?.finishLeave(proceeding: true)
            }
        )
    }

    /// Save: the footer's own Save. A save that needs a name opens
    /// the naming prompt and the leave waits for it; one that
    /// fails keeps the draft and cancels the leave.
    func saveAndLeave(_ pending: PendingDiscard) {
        pendingDiscard = nil
        switch primarySaveAction {
        case .saveAsNewProfile:
            leaveNamingRequested = true
            return
        case .saveLua: saveLuaSource()
        case .updateStoredProfile: saveEditedProfile()
        case .updateActiveProfile: updateActiveProfile()
        case .saveGlobalsOnly: saveGlobalsWhilePaused()
        }
        finishLeave(proceeding: !isDirty)
    }

    /// The naming prompt closed, saved or not: a waiting leave
    /// goes ahead only if the save landed.
    func namingEnded() {
        finishLeave(proceeding: !isDirty)
    }

    /// The dialog went away without a button — AppKit ending the
    /// sheet at a quit. Settled a turn later, so a button that
    /// runs after this setter (SwiftUI does not contract the
    /// order) answers first.
    func discardDialogDismissed() {
        guard let pending = pendingDiscard else { return }
        guard pending.isLeave else { return pendingDiscard = nil }
        CFRunLoopPerformBlock(
            CFRunLoopGetMain(),
            CFRunLoopMode.commonModes.rawValue
        ) { [weak self] in
            MainActor.assumeIsolated {
                guard self?.pendingDiscard?.id == pending.id else {
                    return
                }
                self?.cancelPendingDiscard()
            }
        }
        CFRunLoopWakeUp(CFRunLoopGetMain())
    }

    func finishLeave(proceeding: Bool) {
        guard let leave = draftLeave else { return }
        draftLeave = nil
        if proceeding { leave.proceed() } else { leave.cancel() }
    }

    /// Whether the footer's Save could run now; the same gates
    /// its button greys on (#335).
    var leaveCanSave: Bool {
        switch primarySaveAction {
        case .saveLua, .updateStoredProfile, .saveGlobalsOnly:
            return true
        case .updateActiveProfile:
            return profileSaveBlockedReason == nil && updateEnabled
        case .saveAsNewProfile:
            return profileSaveBlockedReason == nil
        }
    }

    /// The existing reason a blocked Save shows.
    var leaveSaveBlockedReason: String? {
        profileSaveBlockedReason ?? updateHint
    }

    private var leaveSaveLabel: String {
        primarySaveAction == .saveAsNewProfile
            ? L("footer.save_as_new_profile", "Save as New Profile…")
            : L("footer.save", "Save")
    }
}
