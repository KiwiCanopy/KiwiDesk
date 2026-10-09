import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

@MainActor
private final class LeaveRegistrar: HotkeyRegistrar {
    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? { 1 }
    func unregister(id: UInt32) {}
}

/// Records what a held close or quit was told.
@MainActor
private final class Outcome {
    var proceeded = 0
    var cancelled = 0
}

/// Closing Settings or quitting with unsaved edits asks Save /
/// Discard / Cancel through the one discard gate, and no draft
/// outlives the window (#2049 ruling). Locale pinned per body
/// (#740).
@Suite("Unsaved edits ask before a close or quit (#2049)")
@MainActor
struct DraftLeaveTests {
    private func makeDirtyModel() throws -> SettingsModel {
        LocalizationManager.shared.select("en")
        let core = makeTestCore(hotkeyRegistrar: LeaveRegistrar())
        try core.saveGuiConfig(GuiConfig())
        let model = makeTestModel(core: core)
        model.config.settings.gapsGlobal.inner.horizontal += 7
        #expect(model.isDirty)
        return model
    }

    private func leave(
        _ model: SettingsModel,
        _ intent: DraftLeave.Intent = .quit
    ) -> Outcome {
        let outcome = Outcome()
        model.leavingDraft(
            intent,
            proceed: { outcome.proceeded += 1 },
            cancel: { outcome.cancelled += 1 }
        )
        return outcome
    }

    @Test("a clean draft leaves at once and asks nothing")
    func cleanLeavesAtOnce() throws {
        LocalizationManager.shared.select("en")
        let model = makeTestModel(
            core: makeTestCore(hotkeyRegistrar: LeaveRegistrar())
        )
        #expect(!model.isDirty)
        let outcome = leave(model)
        #expect(outcome.proceeded == 1)
        #expect(model.pendingDiscard == nil)
    }

    @Test("unsaved edits ask Save, Discard, Cancel")
    func dirtyAsks() throws {
        let model = try makeDirtyModel()
        let outcome = leave(model, .close)
        let pending = try #require(model.pendingDiscard)
        #expect(pending.kind == .leave(.close))
        #expect(
            pending.title == "Save your changes before closing Settings?"
        )
        #expect(pending.confirmLabel == "Discard")
        #expect(pending.saveLabel != nil)
        #expect(!pending.cancelIsDefault)
        #expect(outcome.proceeded == 0 && outcome.cancelled == 0)
        let quit = leave(model, .quit)
        // One pending slot: the earlier leave is cancelled.
        #expect(outcome.cancelled == 1)
        #expect(
            model.pendingDiscard?.title
                == "Save your changes before quitting KiwiDesk?"
        )
        #expect(quit.proceeded == 0)
    }

    @Test("Discard drops the draft and goes ahead")
    func discardProceeds() throws {
        let model = try makeDirtyModel()
        let outcome = leave(model)
        model.confirmPendingDiscard(try #require(model.pendingDiscard))
        #expect(!model.isDirty)
        #expect(outcome.proceeded == 1)
        #expect(outcome.cancelled == 0)
        #expect(model.draftLeave == nil)
    }

    @Test("Cancel keeps the draft and stops the leave")
    func cancelStops() throws {
        let model = try makeDirtyModel()
        let outcome = leave(model)
        model.cancelPendingDiscard()
        #expect(model.isDirty)
        #expect(outcome.cancelled == 1)
        #expect(outcome.proceeded == 0)
    }

    @Test("a dialog closed with no button cancels a turn later")
    func dismissalCancelsLater() throws {
        let model = try makeDirtyModel()
        let outcome = leave(model)
        model.discardDialogDismissed()
        #expect(outcome.cancelled == 0)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        #expect(outcome.cancelled == 1)
        #expect(model.pendingDiscard == nil)
    }

    @Test("a button answering after the dismissal wins")
    func buttonAfterDismissalWins() throws {
        let model = try makeDirtyModel()
        let outcome = leave(model)
        let pending = try #require(model.pendingDiscard)
        model.discardDialogDismissed()
        model.confirmPendingDiscard(pending)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        #expect(outcome.proceeded == 1)
        #expect(outcome.cancelled == 0)
    }

    @Test("a Save that needs a name waits for the naming prompt")
    func saveAsNewWaitsForName() throws {
        let model = try makeDirtyModel()
        #expect(model.primarySaveAction == .saveAsNewProfile)
        let outcome = leave(model)
        let pending = try #require(model.pendingDiscard)
        #expect(pending.saveLabel == "Save as New Profile…")
        model.saveAndLeave(pending)
        #expect(model.leaveNamingRequested)
        #expect(model.pendingDiscard == nil)
        #expect(outcome.proceeded == 0 && outcome.cancelled == 0)
        // The prompt cancelled: nothing saved, the leave stops.
        model.namingEnded()
        #expect(model.isDirty)
        #expect(outcome.cancelled == 1)
    }

    @Test("a blocked Save offers Discard and Cancel with its reason")
    func blockedSaveOffersTwo() throws {
        let model = try makeDirtyModel()
        model.coreHold = .permissionMissing
        #expect(model.primarySaveAction == .saveAsNewProfile)
        _ = leave(model)
        let pending = try #require(model.pendingDiscard)
        #expect(pending.saveLabel == nil)
        #expect(pending.message == model.profileSaveBlockedReason)
    }

    @Test("a fresh open drops a draft; a raise keeps it")
    func freshOpenReloads() throws {
        let model = try makeDirtyModel()
        model.prepareToShow(windowShown: true)
        #expect(model.isDirty)
        model.prepareToShow(windowShown: false)
        #expect(!model.isDirty)
    }
}
