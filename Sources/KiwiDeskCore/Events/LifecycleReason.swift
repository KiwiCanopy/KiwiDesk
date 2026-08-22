import Foundation

/// The shared settle window after a native desktop switch —
/// the ONE home for the "1 second" (#40, AGENTS §5 mirror
/// rule): destroys inside it classify as vanished, and focus
/// events inside it must not flip Spaces
/// (`KiwiCore+SpaceCommands`).
public enum NativeSwitch {
    public static let settle: TimeInterval = 1
}

/// Why a window left the visible set (#40). Lifecycle events
/// track visibility, not app lifecycle: a native macOS Space
/// switch makes every window on the old desktop vanish from
/// AX. The reason payload lets consumers tell a real close
/// from that artifact without heuristics of their own.
public enum WindowGoneReason: String, Sendable {
    case closed
    case minimized
    case vanished
    /// The window's APP hid — ⌘H, or an Electron app hiding
    /// itself as its last window closes (#913). Its own value
    /// rather than `closed`, which this vocabulary defines as a
    /// real close, and rather than `vanished`, which a consumer
    /// reads as the native-Space artifact: the window is still
    /// there, one gesture away, and it comes back as `returned`.
    /// Not produced by `classify` — a hide is explicit, like a
    /// minimize, so there is nothing to infer from timing; the
    /// `.windowHidden` event carries it directly.
    case hidden

    /// Pure classifier. Minimize wins (the AX notification is
    /// explicit); a destroy inside the native-switch settle
    /// window reads as vanished — the switch timestamp is set
    /// before the reconcile burst on the same run-loop turn,
    /// so the window only absorbs slow-AX stragglers (same 1 s
    /// precedent as the focus-follow guard). A real close in
    /// that window misreads as vanished — cosmetic, and the
    /// dirty-flag + re-query consumer pattern self-heals.
    public static func classify(
        wasMinimized: Bool,
        sinceNativeSwitch: TimeInterval
    ) -> WindowGoneReason {
        if wasMinimized { return .minimized }
        return sinceNativeSwitch <= NativeSwitch.settle
            ? .vanished : .closed
    }
}

/// Why a window entered the visible set (#40). Purely
/// structural — no timing: a tracked minimized id means
/// deminiaturize, a remembered space means it came back from
/// another native desktop (or a session restore).
public enum WindowAppearReason: String, Sendable {
    case new
    case returned
    case restored

    public static func classify(
        wasMinimized: Bool,
        hadRememberedSpace: Bool
    ) -> WindowAppearReason {
        if wasMinimized { return .restored }
        return hadRememberedSpace ? .returned : .new
    }
}
