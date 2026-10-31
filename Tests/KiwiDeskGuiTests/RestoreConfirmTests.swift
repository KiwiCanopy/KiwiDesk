import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The restore confirm is one native alert: one destructive
/// Restore, Cancel on Return, and the "Include init.lua" checkbox
/// only where the backup offers both restores (#2730).
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

    @Test("the checkbox shows only where there is a choice")
    func checkboxOnlyWithAChoice() {
        let both = RestoreConfirm.alert(for: choices(nil, withInitLua: true))
        #expect(both.0.accessoryView != nil)
        #expect(both.1?.isOn == false)
        for shape in [
            choices(nil, withInitLua: false),
            choices(.luaOwnsThisMac, withInitLua: true),
            choices(.empty, withInitLua: true),
        ] {
            let (alert, option) = RestoreConfirm.alert(for: shape)
            #expect(alert.accessoryView == nil)
            #expect(option == nil)
        }
    }

    @Test("Restore runs the box's answer, or the only restore offered")
    func restoreRuns() {
        let both = choices(nil, withInitLua: true)
        #expect(!RestoreConfirm.replacingInitLua(both, ticked: false))
        #expect(RestoreConfirm.replacingInitLua(both, ticked: true))
        #expect(
            !RestoreConfirm.replacingInitLua(
                choices(nil, withInitLua: false),
                ticked: nil
            )
        )
        #expect(
            RestoreConfirm.replacingInitLua(
                choices(.luaOwnsThisMac, withInitLua: true),
                ticked: nil
            )
        )
        #expect(
            RestoreConfirm.replacingInitLua(
                choices(.empty, withInitLua: true),
                ticked: nil
            )
        )
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
    }
}
