import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The restore confirm is one native alert: one destructive
/// Restore, Cancel on Return, and the "Include init.lua" checkbox
/// wherever the backup's init.lua may come, ticked before a
/// restore that needs it (#2730).
@Suite("Restore confirm alert (#2730)")
@MainActor
struct RestoreConfirmTests {
    private func choices(
        _ refusal: SetupBundleError?,
        withInitLua: Bool
    ) -> RestoreChoices {
        RestoreChoices(plainRefusal: refusal, withInitLua: withInitLua)
    }

    @Test("one Restore, destructive, and Return cancels")
    func buttons() {
        LocalizationManager.shared.select("en")
        let (alert, _) = RestoreConfirm.alert(
            for: choices(nil, withInitLua: true)
        )
        #expect(alert.buttons.count == 2)
        let restore = alert.buttons[0]
        let cancel = alert.buttons[1]
        #expect(restore.title == SetupBackupText.restoreLabel)
        #expect(restore.hasDestructiveAction)
        #expect(!cancel.hasDestructiveAction)
        #expect(restore.keyEquivalent.isEmpty)
        #expect(cancel.keyEquivalent == "\r")
    }

    @Test("the checkbox shows wherever the backup's init.lua may come")
    func checkboxWithInitLua() {
        for shape in [
            choices(nil, withInitLua: true),
            choices(.luaOwnsThisMac, withInitLua: true),
            choices(.empty, withInitLua: true),
        ] {
            let (alert, option) = RestoreConfirm.alert(for: shape)
            #expect(alert.accessoryView != nil)
            #expect(option?.isOn == false)
        }
        let (alert, option) = RestoreConfirm.alert(
            for: choices(nil, withInitLua: false)
        )
        #expect(alert.accessoryView == nil)
        #expect(option == nil)
    }

    @Test("a restore that only comes with init.lua waits for the box")
    func requiredBoxGatesRestore() {
        for shape in [
            choices(.luaOwnsThisMac, withInitLua: true),
            choices(.empty, withInitLua: true),
        ] {
            let (alert, _) = RestoreConfirm.alert(for: shape)
            #expect(!alert.buttons[0].isEnabled)
            #expect(!RestoreConfirm.canRestore(shape, ticked: false))
            #expect(RestoreConfirm.canRestore(shape, ticked: true))
        }
        let (alert, _) = RestoreConfirm.alert(
            for: choices(nil, withInitLua: true)
        )
        #expect(alert.buttons[0].isEnabled)
    }

    @Test("Restore runs the box's answer; Cancel runs nothing")
    func answers() {
        let first = NSApplication.ModalResponse.alertFirstButtonReturn
        let second = NSApplication.ModalResponse.alertSecondButtonReturn
        let both = choices(nil, withInitLua: true)
        let plain = choices(nil, withInitLua: false)
        let owned = choices(.luaOwnsThisMac, withInitLua: true)
        #expect(RestoreConfirm.answer(first, both, ticked: false) == false)
        #expect(RestoreConfirm.answer(first, both, ticked: true) == true)
        #expect(RestoreConfirm.answer(first, plain, ticked: false) == false)
        #expect(RestoreConfirm.answer(first, owned, ticked: true) == true)
        #expect(RestoreConfirm.answer(first, owned, ticked: false) == nil)
        for shape in [both, plain, owned] {
            #expect(RestoreConfirm.answer(second, shape, ticked: true) == nil)
            #expect(
                RestoreConfirm.answer(.cancel, shape, ticked: true) == nil
            )
        }
    }

    @Test("Settings asks through the alert, not a SwiftUI dialog")
    func settingsAsksThroughTheAlert() throws {
        let source = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Sections/"
                        + "GeneralSection+Backup.swift"
                )
        )
        #expect(source.contains("RestoreConfirm.ask("))
        #expect(!source.contains(".confirmationDialog("))
        // The alert's answer reaches the restore unchanged.
        #expect(
            source.occurrences(
                of: "replacingInitLua: replacingInitLua"
            ) == 1
        )
        let confirm = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Components/General/"
                        + "RestoreConfirm.swift"
                )
        )
        #expect(confirm.contains("answer(response, choices, ticked:"))
        #expect(confirm.contains("restore(replacing)"))
        // Return took Cancel's Escape, so the sheet hands it back.
        #expect(confirm.contains("let escape = cancelsOnEscape(alert)"))
        #expect(confirm.contains("NSEvent.removeMonitor(escape)"))
    }
}
