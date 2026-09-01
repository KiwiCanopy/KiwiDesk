import AppKit

/// What is driving the navigation happening right now — the one
/// input-source reading the shell's focus statements share
/// (#991). The argument is `.claude/rules/gui.md` ▸ the keyboard
/// path.
enum SettingsInputSource {
    /// Whether the event macOS is dispatching is one that would
    /// have moved focus on its own.
    ///
    /// Refuses a positive MOUSE event and nothing else, which
    /// fails toward stating a destination. Two traps make the
    /// obvious `== .keyDown` wrong: VoiceOver presses a control
    /// through `AXPress` with no `NSEvent` behind it at all, and
    /// `currentEvent` is the last event RETRIEVED rather than
    /// one cleared after dispatch — so a test that must see a
    /// key press states nothing for a screen-reader user, whose
    /// cursor then follows focus to a view the navigation just
    /// destroyed.
    ///
    /// `NSApp` is an implicitly-unwrapped optional and is nil in
    /// a process with no `NSApplication` — a test host included,
    /// where it traps rather than returning nil (crash, 2026-09-01).
    @MainActor static var movesFocus: Bool {
        switch NSApp?.currentEvent?.type {
        case .leftMouseDown, .leftMouseUp, .rightMouseDown,
            .rightMouseUp, .otherMouseDown, .otherMouseUp:
            return false
        default:
            return true
        }
    }
}
