import AppKit

/// Whether the focus change now landing was caused by the mouse
/// AND is a stray ring rather than the focus the click asked for.
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
    /// The decision, pure so both its answers are pinned without
    /// an `NSApplication` (`ClickBornFocusTests`).
    ///
    /// `textEditingOwnsFocus` is the #1309 arm and it comes
    /// FIRST. A container's `.focused($x)` reads "focus is
    /// somewhere within me", so a click into a `TextField`
    /// inside the Settings detail pane turns the pane's binding
    /// true — and a refusal spelled on that signal answered by
    /// the button state alone clears the field the user just
    /// clicked, as collateral. Measured on device 2026-09-07:
    /// every failing click logged `focused=true`, then the
    /// pane's refusal, then `focused=false`, so the hex field
    /// took the caret for one to six milliseconds and lost it.
    ///
    /// The arm is narrow on purpose. It withholds the refusal
    /// only where a click has put the caret in an editable
    /// field, which no `.focusable()` custom view can be — so a
    /// leaf control's refusal (a slider, a segmented picker, a
    /// chip) is untouched and #991 keeps every ring it removed.
    static func refuses(
        mouseHeld: Bool,
        dispatchingMouseEvent: Bool,
        textEditingOwnsFocus: Bool
    ) -> Bool {
        if textEditingOwnsFocus { return false }
        return mouseHeld || dispatchingMouseEvent
    }

    /// BOTH readings, because they miss different cases: a
    /// button still held (a drag), and a click already completed
    /// on mouse-UP, where nothing is pressed by the time the
    /// focus change is observed.
    @MainActor static var isClickBorn: Bool {
        refuses(
            mouseHeld: NSEvent.pressedMouseButtons != 0,
            dispatchingMouseEvent: dispatchingMouseEvent,
            textEditingOwnsFocus: textEditingOwnsFocus
        )
    }

    /// `NSApp?`, never `NSApp`: it is implicitly unwrapped and
    /// nil in a process with no `NSApplication`, where the
    /// force-unwrap traps (crash, 2026-09-01).
    @MainActor private static var dispatchingMouseEvent: Bool {
        switch NSApp?.currentEvent?.type {
        case .leftMouseDown, .leftMouseUp, .rightMouseDown,
            .rightMouseUp, .otherMouseDown, .otherMouseUp:
            return true
        default:
            return false
        }
    }

    /// Whether an editable text responder holds the focus.
    ///
    /// A control that takes focus for itself installs its own
    /// responder — a field editor — where a plain focusable view
    /// leaves the `NSHostingView` in place. That is the one fact
    /// separating "the pane took a ring" from "the field took
    /// the caret", because the pane's `FocusState` says the same
    /// thing in both. Device log, 2026-09-07: a hex-field click
    /// reports `_SystemTextFieldFieldEditor`, a click on the
    /// pane's own background reports the hosting view, and by
    /// the time a background click is seen the previous field's
    /// editor is already gone.
    @MainActor private static var textEditingOwnsFocus: Bool {
        guard
            let text = NSApp?.keyWindow?.firstResponder as? NSText
        else { return false }
        return text.isEditable
    }
}
