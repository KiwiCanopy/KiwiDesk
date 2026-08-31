import AppKit

/// What is driving the navigation happening right now — the ONE
/// input-source reading the shell's focus statements share
/// (#991).
///
/// macOS moves keyboard focus for a key press and does not move
/// it for a click; Tab simply restarts from the top of the window
/// after a click, which the owner confirmed in System Settings.
/// Stating a destination on a mouse navigation therefore draws a
/// focus ring the platform would not have drawn.
///
/// The fix belongs HERE and not at the ring: a focus ring is the
/// user's own accessibility surface — Full Keyboard Access owns
/// its colour, contrast and size — so `.focusEffectDisabled()` is
/// the cheap direction `docs/design-decisions.md` ▸ *a focus ring
/// is the platform's* forbids. Move focus only when the platform
/// would, and there is nothing focused to ring.
enum SettingsInputSource {
    /// Whether the event macOS is dispatching right now is a key
    /// press. `.keyDown` is the whole keyboard set that reaches a
    /// navigation: Space and Return on a focused control, Return
    /// on a search result, Escape, and ⌘[ all arrive as one. A
    /// click arrives as a mouse event and a programmatic
    /// navigation — a deep link, a repair — as no event at all,
    /// and neither should move focus.
    @MainActor static var isKeyboard: Bool {
        NSApp.currentEvent?.type == .keyDown
    }
}
