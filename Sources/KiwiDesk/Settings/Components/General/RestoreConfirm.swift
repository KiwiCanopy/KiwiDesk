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
        let escape = cancelsOnEscape(alert)
        alert.beginSheetModal(for: window) { response in
            if let escape { NSEvent.removeMonitor(escape) }
            let ticked = option?.isOn ?? false
            guard let replacing = answer(response, choices, ticked: ticked)
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
        let cancel = alert.addButton(
            withTitle: L("spaces.delete_confirm.cancel", "Cancel")
        )
        // Replaces saved data: Return and Escape cancel, Restore
        // takes a click.
        confirm.keyEquivalent = ""
        cancel.keyEquivalent = "\r"
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

    /// Escape presses Cancel. NSAlert gives Escape to the button
    /// titled Cancel through its key equivalent, which Return takes
    /// here (measured 2026-10-31: the sheet then ignores Escape).
    private static func cancelsOnEscape(_ alert: NSAlert) -> Any? {
        let cancel = alert.buttons[1]
        return NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            event in
            guard event.window === alert.window, event.keyCode == 53,
                event.modifierFlags
                    .intersection(.deviceIndependentFlagsMask).isEmpty
            else { return event }
            cancel.performClick(nil)
            return nil
        }
    }

    /// Restore needs the box ticked where the backup restores only
    /// with its init.lua, so running it is never a default (#2517).
    static func canRestore(_ choices: RestoreChoices, ticked: Bool) -> Bool {
        choices.plain || (choices.withInitLua && ticked)
    }

    /// Whether init.lua comes too for `response`, nil on anything
    /// but Restore.
    static func answer(
        _ response: NSApplication.ModalResponse,
        _ choices: RestoreChoices,
        ticked: Bool
    ) -> Bool? {
        guard response == .alertFirstButtonReturn,
            canRestore(choices, ticked: ticked)
        else { return nil }
        return choices.withInitLua && ticked
    }
}
