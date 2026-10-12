import AppKit

/// The standard menu chords a non-activating key panel answers
/// itself (#1875): KiwiDesk is not the active app while one is up,
/// so its main menu cannot be counted on to carry ⌘W or the edit
/// chords to the panel and its field. Pure, so every chord is
/// testable without a panel.
enum PanelKeyEquivalents {
    static func action(
        for key: String,
        modifiers: NSEvent.ModifierFlags
    ) -> Selector? {
        let held = modifiers.intersection(
            [.shift, .command, .option, .control]
        )
        switch (key.lowercased(), held) {
        case ("w", .command): return #selector(NSWindow.performClose(_:))
        case ("v", .command): return #selector(NSText.paste(_:))
        case ("c", .command): return #selector(NSText.copy(_:))
        case ("x", .command): return #selector(NSText.cut(_:))
        case ("a", .command): return #selector(NSText.selectAll(_:))
        case ("z", .command): return Selector(("undo:"))
        case ("z", [.command, .shift]): return Selector(("redo:"))
        default: return nil
        }
    }

    /// Sends `event`'s chord down the responder chain from
    /// `window`; true where the chord is one of the above.
    @MainActor
    static func perform(_ event: NSEvent, in window: NSWindow) -> Bool {
        guard
            let action = action(
                for: event.charactersIgnoringModifiers ?? "",
                modifiers: event.modifierFlags
            )
        else { return false }
        return NSApplication.shared.sendAction(action, to: nil, from: window)
    }
}
