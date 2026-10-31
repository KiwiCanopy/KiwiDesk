import AppKit

/// An alert whose Cancel is the default (#2826): Return and Escape
/// both press Cancel, the first button takes a click. NSAlert gives
/// Escape to Cancel through that button's key equivalent, so moving
/// Return onto it takes Escape away (measured 2026-10-31); a key-down
/// monitor hands Escape back while the alert is up.
@MainActor
enum CancelDefault {
    /// Moves Return from the first button onto the second, Cancel.
    static func prepare(_ alert: NSAlert) {
        alert.buttons[0].keyEquivalent = ""
        alert.buttons[1].keyEquivalent = "\r"
    }

    /// Runs `alert` app-modal.
    static func runModal(_ alert: NSAlert) -> NSApplication.ModalResponse {
        prepare(alert)
        let escape = watchEscape(alert)
        defer { if let escape { NSEvent.removeMonitor(escape) } }
        return alert.runModal()
    }

    /// Runs `alert` as a sheet over `window`; `done` hears the answer.
    static func beginSheet(
        _ alert: NSAlert,
        over window: NSWindow,
        then done: @escaping (NSApplication.ModalResponse) -> Void
    ) {
        prepare(alert)
        let escape = watchEscape(alert)
        alert.beginSheetModal(for: window) { response in
            if let escape { NSEvent.removeMonitor(escape) }
            done(response)
        }
    }

    /// A bare Escape press; Caps Lock is no modifier.
    static func isEscape(_ event: NSEvent) -> Bool {
        event.keyCode == 53
            && event.modifierFlags
                .intersection([.command, .option, .control, .shift])
                .isEmpty
    }

    private static func watchEscape(_ alert: NSAlert) -> Any? {
        let cancel = alert.buttons[1]
        return NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            event in
            guard event.window === alert.window, isEscape(event)
            else { return event }
            cancel.performClick(nil)
            return nil
        }
    }
}
