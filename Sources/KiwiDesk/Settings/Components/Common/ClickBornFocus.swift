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
    /// The decision, pure so every answer is pinned without an
    /// `NSApplication` (`ClickBornFocusTests`).
    ///
    /// `focusMayBeADescendant` is the caller's, never inferred:
    /// a CONTAINER's `.focused($x)` reads "focus is within me",
    /// so a click into a `TextField` inside it turns the binding
    /// true and the refusal clears the field the user aimed at
    /// (#1309). A leaf control has no descendant to confuse
    /// itself with and passes `false`, which is what keeps
    /// #991's rings — the arm is unreachable for it rather than
    /// merely unlikely.
    static func refuses(
        mouseHeld: Bool,
        dispatchingMouseEvent: Bool,
        focusMayBeADescendant: Bool,
        textEditingOwnsFocus: Bool
    ) -> Bool {
        if focusMayBeADescendant, textEditingOwnsFocus {
            return false
        }
        return mouseHeld || dispatchingMouseEvent
    }

    /// BOTH mouse readings, because they miss different cases: a
    /// button still held (a drag), and a click already completed
    /// on mouse-UP, where nothing is pressed by the time the
    /// focus change is observed.
    @MainActor static func isClickBorn(
        focusMayBeADescendant: Bool
    ) -> Bool {
        refuses(
            mouseHeld: NSEvent.pressedMouseButtons != 0,
            dispatchingMouseEvent: dispatchingMouseEvent,
            focusMayBeADescendant: focusMayBeADescendant,
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

    /// Whether an editable text responder holds the focus — the
    /// one fact separating "a container took a ring" from "the
    /// field inside it took the caret", which its `FocusState`
    /// spells identically (#1309).
    ///
    /// Stated residue: this asks the KEY window, not the window
    /// the binding lives in, which no `FocusState` reading can
    /// reach from here. A click into a background window makes
    /// it key before the focus change is observed, so the two
    /// agree on the measured path — an editable responder in a
    /// panel above (`NSColorPanel` carries hex fields of its
    /// own) is the case that owes a device sitting rather than
    /// an argument. `ClickAwayResignsFocus` (#93) asks the same
    /// question of its own window, and resigns what this reads.
    @MainActor private static var textEditingOwnsFocus: Bool {
        guard
            let text = NSApp?.keyWindow?.firstResponder as? NSText
        else { return false }
        return text.isEditable
    }
}
