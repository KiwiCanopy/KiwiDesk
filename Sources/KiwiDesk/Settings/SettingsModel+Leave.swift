import Foundation
import KiwiDeskCore

/// A close or quit held by the unsaved-edits question (#2049):
/// what runs once it is answered.
struct DraftLeave {
    enum Intent: Equatable {
        case close
        case quit
    }

    let intent: Intent
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
        draftLeave = DraftLeave(
            intent: intent,
            proceed: proceed,
            cancel: cancel
        )
        let canSave = primarySaveEnabled
        let lost = L(
            "discard.leave.message",
            "If you don't save, your changes will be lost."
        )
        pendingDiscard = PendingDiscard(
            kind: .leave(intent),
            message: canSave
                ? lost : (primarySaveBlockedReason ?? lost),
            confirmLabel: L("discard.leave.confirm", "Discard"),
            saveLabel: canSave ? primarySaveLabel : nil,
            perform: { [weak self] in
                self?.revert()
                self?.finishLeave(proceeding: true)
            }
        )
    }

    /// A quit while Settings is open with unsaved edits (#2049):
    /// asks, or leaves the question already up as it is. An
    /// in-place restart intent is withdrawn while the question
    /// waits and re-armed, same source, on the answer, so a Cancel
    /// leaves none armed and a late answer still restarts in place.
    /// `terminate` runs once Save landed or Discard ran.
    func askBeforeQuit(terminate: @escaping @MainActor () -> Void) {
        guard draftLeave == nil else { return }
        let restart = core.withdrawInPlaceRestart()
        leavingDraft(
            .quit,
            proceed: { [weak self] in
                if let restart {
                    self?.core.rearmInPlaceRestart(restart)
                }
                self?.quitAnswered = true
                terminate()
            },
            cancel: {}
        )
    }

    /// Save: the one primary Save. One that needs a name opens the
    /// naming prompt and the leave waits for it (`namingEnded`);
    /// one that fails keeps the draft and cancels the leave.
    func saveAndLeave(_ pending: PendingDiscard) {
        pendingDiscard = nil
        let needsName = primarySaveAction == .saveAsNewProfile
        performPrimarySave()
        guard !needsName else { return }
        finishLeave(proceeding: !isDirty)
    }

    /// The naming prompt went away — saved, cancelled or torn
    /// down: a waiting leave goes ahead only if the save landed.
    func namingEnded() {
        finishLeave(proceeding: !isDirty)
    }

    /// The dialog presenting `id` went away. A leave is settled a
    /// turn later, so a button that runs after this setter
    /// (SwiftUI does not contract the order) answers first; only
    /// the dismissed presentation is ever cancelled.
    func discardDialogDismissed(_ id: UUID?) {
        guard let id, pendingDiscard?.id == id else { return }
        guard pendingDiscard?.isLeave == true else {
            return pendingDiscard = nil
        }
        CFRunLoopPerformBlock(
            CFRunLoopGetMain(),
            CFRunLoopMode.commonModes.rawValue
        ) { [weak self] in
            MainActor.assumeIsolated {
                guard self?.pendingDiscard?.id == id else { return }
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

    /// A quit that cannot wait for an answer (SIGTERM): the draft
    /// and any question about it go.
    func dropDraftForQuit() {
        pendingDiscard = nil
        draftLeave = nil
        if isDirty { revert() }
    }
}
