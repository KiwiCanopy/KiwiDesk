import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

@MainActor
private final class DiscardRegistrar: HotkeyRegistrar {
    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? { 1 }
    func unregister(id: UInt32) {}
}

/// `SettingsModel.discardingEdits` is the one gate every
/// edit-dropping path routes through (#515). Its contract: run
/// now when clean, park when dirty, and never do both.
///
/// The structural half — that each path actually *uses* it — is
/// `DiscardGateParityTests`; this suite pins the behaviour.
@Suite("Discard gate")
@MainActor
struct DiscardGateTests {
    private func makeModel() throws -> SettingsModel {
        let core = KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-discard-\(UUID().uuidString)"
                ),
            hotkeyRegistrar: DiscardRegistrar()
        )
        try core.saveGuiConfig(GuiConfig())
        return SettingsModel(core: core)
    }

    /// Dirties the model the way a real edit does — through
    /// `config`, whose `didSet` recomputes against the clean
    /// baseline. Latching `isDirty` directly would test a flag
    /// the gate never sees in production.
    private func makeDirtyModel() throws -> SettingsModel {
        let model = try makeModel()
        model.config.settings.gapsGlobal.inner.horizontal += 7
        #expect(model.isDirty)
        return model
    }

    @Test("runs immediately with nothing staged")
    func runsWhenClean() throws {
        let model = try makeModel()
        #expect(!model.isDirty)
        var ran = false
        model.discardingEdits(
            message: "m",
            confirmLabel: "c"
        ) { ran = true }
        #expect(ran)
        #expect(model.pendingDiscard == nil)
    }

    @Test("parks the action while edits are staged")
    func parksWhenDirty() throws {
        let model = try makeDirtyModel()
        var ran = false
        model.discardingEdits(
            message: "m",
            confirmLabel: "c"
        ) { ran = true }
        #expect(!ran)
        #expect(model.pendingDiscard != nil)
    }

    @Test("the parked action carries its own copy")
    func parkedActionCarriesCopy() throws {
        let model = try makeDirtyModel()
        model.discardingEdits(
            message: "the message",
            confirmLabel: "the verb"
        ) {}
        #expect(model.pendingDiscard?.message == "the message")
        #expect(
            model.pendingDiscard?.confirmLabel == "the verb"
        )
    }

    /// Confirm clears the state BEFORE running. Two gated
    /// actions flip `editingLua` and re-mount the view tree, so
    /// leaving the clear to the dialog's dismissal would race
    /// that teardown and a surviving `pendingDiscard` would
    /// re-present for an action that already ran.
    @Test("confirming clears the state, then runs it once")
    func confirmRunsParkedAction() throws {
        let model = try makeDirtyModel()
        var ran = 0
        var stateAtRun: PendingDiscard?
        model.discardingEdits(
            message: "m",
            confirmLabel: "c"
        ) {
            ran += 1
            stateAtRun = model.pendingDiscard
        }
        model.confirmPendingDiscard()
        #expect(ran == 1)
        #expect(stateAtRun == nil)
        #expect(model.pendingDiscard == nil)
    }

    /// Idempotent: a second confirm has nothing to run.
    @Test("confirming twice runs the action once")
    func confirmIsIdempotent() throws {
        let model = try makeDirtyModel()
        var ran = 0
        model.discardingEdits(
            message: "m",
            confirmLabel: "c"
        ) { ran += 1 }
        model.confirmPendingDiscard()
        model.confirmPendingDiscard()
        #expect(ran == 1)
    }

    /// Cancelling is the dialog clearing `pendingDiscard`. The
    /// action must never have run, and the edits must survive —
    /// the whole point of the gate.
    @Test("cancelling drops the action and keeps the edits")
    func cancelKeepsEdits() throws {
        let model = try makeDirtyModel()
        let staged = model.config.settings
            .gapsGlobal.inner.horizontal
        var ran = false
        model.discardingEdits(
            message: "m",
            confirmLabel: "c"
        ) { ran = true }
        model.cancelPendingDiscard()
        #expect(!ran)
        #expect(model.isDirty)
        #expect(
            model.config.settings.gapsGlobal.inner
                .horizontal == staged
        )
    }

    /// Two requests without an intervening dismissal replace
    /// rather than merge, so no parked action is ever silently
    /// dropped on the floor while its copy stays on screen.
    /// (A presented `confirmationDialog` does not re-read its
    /// `presenting:` value, so the UI keeps showing the first
    /// message — this pins the model side, which is the half a
    /// test can reach.)
    @Test("a second request replaces the first")
    func secondRequestReplacesFirst() throws {
        let model = try makeDirtyModel()
        var ranFirst = false
        var ranSecond = false
        model.discardingEdits(
            message: "first",
            confirmLabel: "c"
        ) { ranFirst = true }
        model.discardingEdits(
            message: "second",
            confirmLabel: "c"
        ) { ranSecond = true }
        #expect(model.pendingDiscard?.message == "second")
        model.confirmPendingDiscard()
        #expect(!ranFirst)
        #expect(ranSecond)
    }
}
