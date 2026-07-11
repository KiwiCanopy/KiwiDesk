import Foundation

/// Why a window left the visible set (#40). Lifecycle events
/// track visibility, not app lifecycle: a native macOS Space
/// switch makes every window on the old desktop vanish from
/// AX. The reason payload lets consumers tell a real close
/// from that artifact without heuristics of their own.
public enum WindowGoneReason: String, Sendable {
    case closed
    case minimized
    case vanished

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
        return sinceNativeSwitch <= 1 ? .vanished : .closed
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
