import AppKit

/// A Hyper press with no Hyper row in the active layer (#2480): the
/// key does nothing, so a pill says why. Silent by ruling, since a
/// beep was the defect, and announced, since VoiceOver sees no pill.
extension KiwiCore {
    func cueBareHyper() {
        let text = Self.bareHyperText
        let symbol = "keyboard"
        if let window = focusedWindowID {
            flashRefusalPill(
                window,
                text: text,
                symbol: symbol,
                announce: true
            )
        } else if let space = state.workspaces.activeSpace,
            let display = state.workspaces.display(of: space),
            let drawn = shelves.drawnStrip(on: display, preferring: .space)
        {
            flashRefusalPill(
                near: drawn.strip,
                on: display,
                edge: drawn.edge,
                text: text,
                symbol: symbol,
                announce: true
            )
        } else {
            borders.announceRefusal(text)
        }
    }

    /// The pill's sentence: a fact, the fix living on the Hyper key
    /// card (ui-designer, #2480).
    static var bareHyperText: String {
        L("keys.hyper.no_shortcut", "No active shortcut uses Hyper")
    }
}
