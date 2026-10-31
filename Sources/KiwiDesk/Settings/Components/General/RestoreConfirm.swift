import AppKit
import KiwiDeskCore

/// The restore confirm (#606, #2730): a native `NSAlert` sheet
/// with one destructive Restore and, wherever the backup carries
/// an init.lua it may restore, Export's "Include init.lua"
/// checkbox, off every time. A sheet, so a quit ends it as Cancel
/// (`QuitSheets`).
@MainActor
enum RestoreConfirm {
    /// Asks over `window` and calls `restore` with whether the
    /// backup's init.lua comes too; nothing is called on Cancel.
    static func ask(
        _ choices: RestoreChoices,
        over window: NSWindow,
        restore: @escaping (_ replacingInitLua: Bool) -> Void
    ) {
        let (alert, option) = alert(for: choices)
        CancelDefault.beginSheet(alert, over: window) { response in
            guard
                let replacing = answer(
                    response,
                    choices,
                    ticked: option?.isOn
                )
            else { return }
            restore(replacing)
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
        alert.addButton(
            withTitle: L("spaces.delete_confirm.cancel", "Cancel")
        )
        // Replaces saved data: Cancel is the default.
        CancelDefault.prepare(alert)
        confirm.isEnabled = canRestore(choices, ticked: false)
        guard choices.withInitLua else { return (alert, nil) }
        let option = BackupInitLuaOption()
        option.onToggle = { ticked in
            confirm.isEnabled = canRestore(choices, ticked: ticked)
        }
        option.view.frame.size = option.view.fittingSize
        alert.accessoryView = option.view
        return (alert, option)
    }

    /// Restore needs the box ticked where the backup restores only
    /// with its init.lua, so running it is never a default (#2517).
    static func canRestore(_ choices: RestoreChoices, ticked: Bool) -> Bool {
        choices.plain || (choices.withInitLua && ticked)
    }

    /// Whether init.lua comes too for `response`, nil on anything
    /// but Restore; `ticked` is the box's state, nil where none shows.
    static func answer(
        _ response: NSApplication.ModalResponse,
        _ choices: RestoreChoices,
        ticked: Bool?
    ) -> Bool? {
        let ticked = ticked ?? false
        guard response == .alertFirstButtonReturn,
            canRestore(choices, ticked: ticked)
        else { return nil }
        return choices.withInitLua && ticked
    }
}
