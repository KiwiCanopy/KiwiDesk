import AppKit

/// A Hyper press with no Hyper row in the active layer (#2480): the
/// key does nothing, so a pill says why. Silent by ruling, since a
/// beep was the defect, and announced, since refusal pills are not.
extension KiwiCore {
    func cueBareHyper() {
        let text = Self.bareHyperText
        let symbol = "keyboard"
        if let window = focusedWindowID {
            flashRefusalPill(window, text: text, symbol: symbol)
        } else if let space = state.workspaces.activeSpace,
            let display = state.workspaces.display(of: space),
            let drawn = shelves.drawnStrip(on: display, preferring: .space)
        {
            flashRefusalPill(
                near: drawn.strip,
                on: display,
                edge: drawn.edge,
                text: text,
                symbol: symbol
            )
        }
        announceBareHyper(text)
    }

    /// The pill's sentence: a fact, the fix living on the Hyper key
    /// card (ui-designer, #2480).
    static var bareHyperText: String {
        L("keys.hyper.no_shortcut", "No active shortcut uses Hyper")
    }

    /// Spoken for VoiceOver, which hears no pill. `NSApp` is nil in
    /// a process with no `NSApplication`, a test host included.
    func announceBareHyper(_ text: String) {
        guard let app = NSApp else { return }
        NSAccessibility.post(
            element: app,
            notification: .announcementRequested,
            userInfo: [
                .announcement: text,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
    }
}
