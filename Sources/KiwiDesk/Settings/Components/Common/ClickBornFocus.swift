import AppKit

/// Whether the focus change now landing was caused by the mouse.
///
/// macOS 26 gives a `.focusable()` custom view keyboard focus on
/// a click, where the platform's own controls take none — so a
/// ring appears for a user who never asked for one (#991's
/// defect; owner eye-confirm on the Settings pane, 2026-09-01).
/// Refuse the focus and there is nothing to ring, which is the
/// direction `docs/design-decisions.md` ▸ *a focus ring is the
/// platform's* requires.
///
/// The PREDICATE is shared; the `onChange` that consults it is
/// spelled at each site on purpose. Folded into a `ViewModifier`
/// taking the `FocusState` binding it silently never fires —
/// reading `wrappedValue` there establishes no dependency, so
/// the refusal compiles, reads correctly, and does nothing
/// (measured 2026-09-01: zero firings, keyboard path included).
///
/// Distinct from `SettingsInputSource`: "the mouse caused this"
/// and "the event being dispatched is a key press" answer
/// different questions, and merging them would refuse
/// programmatic focus, which this must allow.
enum ClickBornFocus {
    /// BOTH readings, because they miss different cases: a
    /// button still held (a drag), and a click already completed
    /// on mouse-UP, where nothing is pressed by the time the
    /// focus change is observed.
    @MainActor static var isClickBorn: Bool {
        if NSEvent.pressedMouseButtons != 0 { return true }
        switch NSApp.currentEvent?.type {
        case .leftMouseDown, .leftMouseUp, .rightMouseDown,
            .rightMouseUp, .otherMouseDown, .otherMouseUp:
            return true
        default:
            return false
        }
    }
}
