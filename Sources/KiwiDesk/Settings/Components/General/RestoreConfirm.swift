import AppKit
import KiwiDeskCore

/// The restore confirm (#606, #2730): a native `NSAlert` sheet
/// with one destructive Restore and, where the backup offers a
/// choice, Export's "Include init.lua" checkbox, off every time.
/// An `NSAlert` sheet, so a quit ends it as Cancel (`QuitSheets`).
@MainActor
enum RestoreConfirm {
    /// Asks over `window` (app-modal where nil) and calls
    /// `restore` with whether the backup's init.lua comes too;
    /// nothing is called on Cancel.
    static func ask(
        _ choices: RestoreChoices,
        over window: NSWindow?,
        restore: @escaping (_ replacingInitLua: Bool) -> Void
    ) {
        let (alert, option) = alert(for: choices)
        let answer = { (response: NSApplication.ModalResponse) in
            guard response == .alertFirstButtonReturn else { return }
            restore(replacingInitLua(choices, ticked: option?.isOn))
        }
        if let window {
            alert.beginSheetModal(for: window, completionHandler: answer)
        } else {
            answer(alert.runModal())
        }
    }

    /// The alert and, where it shows, its checkbox.
    static func alert(
        for choices: RestoreChoices
    ) -> (NSAlert, BackupInitLuaOption?) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L(
            "general.advanced.backup.restore.confirm.title",
            "Restore from this backup?"
        )
        alert.informativeText = SetupBackupText.restoreMessage(choices)
        let confirm = alert.addButton(
            withTitle: SetupBackupText.restoreLabel
        )
        confirm.hasDestructiveAction = true
        let cancel = alert.addButton(
            withTitle: L("spaces.delete_confirm.cancel", "Cancel")
        )
        // Replaces saved data: Return and Escape both cancel.
        confirm.keyEquivalent = ""
        cancel.keyEquivalent = "\r"
        guard offersInitLuaChoice(choices) else { return (alert, nil) }
        let option = BackupInitLuaOption(hasInitLua: true, luaOwned: false)
        option.view.frame.size = option.view.fittingSize
        alert.accessoryView = option.view
        return (alert, option)
    }

    /// The checkbox shows only where both restores are offered;
    /// otherwise the message names the one there is.
    static func offersInitLuaChoice(_ choices: RestoreChoices) -> Bool {
        choices.plain && choices.withInitLua
    }

    /// The restore Restore runs: the box's answer where it shows,
    /// else the only restore offered.
    static func replacingInitLua(
        _ choices: RestoreChoices,
        ticked: Bool?
    ) -> Bool {
        guard offersInitLuaChoice(choices) else { return !choices.plain }
        return ticked ?? false
    }
}
