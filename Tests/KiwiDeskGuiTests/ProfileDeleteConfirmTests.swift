import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

@MainActor
private final class DeleteRegistrar: HotkeyRegistrar {
    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? { 1 }
    func unregister(id: UInt32) {}
}

/// A profile delete asks every time, clean or dirty, in ONE
/// dialog whose Return picks Cancel (#1619). Which call sites
/// take this gate is `DiscardGateParityTests`' half. Locale
/// pinned per body (#740).
@Suite("Profile delete confirm (#1619)")
@MainActor
struct ProfileDeleteConfirmTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore(hotkeyRegistrar: DeleteRegistrar())
        try core.saveGuiConfig(GuiConfig())
        return makeTestModel(core: core)
    }

    @Test("parks even with nothing staged")
    func parksWhenClean() throws {
        pinEnglish()
        let model = try makeModel()
        #expect(!model.isDirty)
        var ran = false
        model.confirmingProfileDelete("Work") { ran = true }
        #expect(!ran)
        let pending = try #require(model.pendingDiscard)
        #expect(pending.title == "Delete \u{201C}Work\u{201D}?")
        #expect(
            pending.message
                == "Its Spaces, layouts, rules and shortcuts will be "
                + "deleted. You can't undo this."
        )
        #expect(pending.confirmLabel == "Delete")
        #expect(pending.cancelIsDefault)
        #expect(pending.cancelLabel == "Cancel")
    }

    /// Staged edits fold into the delete's own message rather
    /// than a discard dialog ahead of it.
    @Test("staged edits fold into the one dialog")
    func dirtyFoldsIntoOneDialog() throws {
        pinEnglish()
        let model = try makeModel()
        model.config.settings.gapsGlobal.inner.horizontal += 7
        #expect(model.isDirty)
        var ran = 0
        model.confirmingProfileDelete("Work") { ran += 1 }
        let pending = try #require(model.pendingDiscard)
        #expect(pending.title == "Delete \u{201C}Work\u{201D}?")
        #expect(pending.message.contains("haven't saved"))
        #expect(pending.cancelIsDefault)
        model.confirmPendingDiscard(pending)
        #expect(ran == 1)
        #expect(model.pendingDiscard == nil)
    }

    @Test("cancelling never deletes")
    func cancelKeepsTheProfile() throws {
        pinEnglish()
        let model = try makeModel()
        var ran = false
        model.confirmingProfileDelete("Work") { ran = true }
        model.cancelPendingDiscard()
        #expect(!ran)
    }

    /// A broken profile's file may not be readable, so its
    /// message names the file rather than what it held.
    @Test("a broken profile's delete names only the file")
    func brokenNamesTheFile() throws {
        pinEnglish()
        let model = try makeModel()
        model.brokenProfiles = [
            BrokenProfile(name: "Work", cause: .malformedJSON)
        ]
        model.confirmingProfileDelete("Work") {}
        let clean = try #require(model.pendingDiscard)
        #expect(clean.message.hasPrefix("This removes the profile file"))
        #expect(!clean.message.contains("haven't saved"))
        model.cancelPendingDiscard()
        model.config.settings.gapsGlobal.inner.horizontal += 7
        model.confirmingProfileDelete("Work") {}
        let dirty = try #require(model.pendingDiscard)
        #expect(dirty.message.hasPrefix("This removes the profile file"))
        #expect(dirty.message.contains("haven't saved"))
        #expect(dirty.cancelIsDefault)
        // A healthy profile beside it keeps the full message.
        model.cancelPendingDiscard()
        model.confirmingProfileDelete("Home") {}
        let healthy = try #require(model.pendingDiscard)
        #expect(healthy.message.hasPrefix("Its Spaces"))
    }

    /// `discard.cancel` reads "keep editing" in several catalogs;
    /// a clean delete has nothing being edited, so its Cancel
    /// takes a key of its own.
    @Test("a delete's Cancel is not the discard dialog's")
    func deleteCancelIsItsOwn() throws {
        LocalizationManager.shared.select("fr")
        defer { LocalizationManager.shared.select("en") }
        let discard = PendingDiscard(
            message: "m",
            confirmLabel: "c",
            perform: {}
        )
        let delete = PendingDiscard(
            kind: .deleteProfile(name: "Work"),
            message: "m",
            confirmLabel: "c",
            perform: {}
        )
        #expect(delete.cancelLabel != discard.cancelLabel)
    }

    /// The plain discard gate keeps its shared title and its
    /// verb-as-default behaviour.
    @Test("the discard gate keeps the shared dialog")
    func discardGateUnchanged() throws {
        pinEnglish()
        let model = try makeModel()
        model.config.settings.gapsGlobal.inner.horizontal += 7
        model.discardingEdits(message: "m", confirmLabel: "c") {}
        let pending = try #require(model.pendingDiscard)
        #expect(pending.kind == .discard)
        #expect(pending.title == "Discard unsaved changes?")
        #expect(!pending.cancelIsDefault)
    }

    /// The host reads the kind's answers, and the Return shortcut
    /// sits on Cancel's chain — never on the destructive button,
    /// where it would make Return delete.
    @Test("the dialog host puts the default on Cancel")
    func hostWiresCancelDefault() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/DiscardConfirm.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace).joined()
        #expect(source.contains("model.pendingDiscard?.title"))
        #expect(
            source.contains("Button(pending.confirmLabel,role:.destructive)")
        )
        #expect(source.contains("Text(pending.message)"))
        let destructive = try #require(
            source.range(of: "role:.destructive")
        )
        let cancel = try #require(
            source.range(of: "Button(pending.cancelLabel,role:.cancel)")
        )
        let end = try #require(source.range(of: "}message:"))
        #expect(destructive.upperBound < cancel.lowerBound)
        let deleteChain = source[destructive.upperBound..<cancel.lowerBound]
        let cancelChain = source[cancel.upperBound..<end.lowerBound]
        #expect(!deleteChain.contains("keyboardShortcut"))
        #expect(
            cancelChain.contains(
                ".keyboardShortcut(pending.cancelIsDefault?"
                    + ".defaultAction:nil)"
            )
        )
    }
}
