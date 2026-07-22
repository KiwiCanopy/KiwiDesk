import CoreGraphics
import Foundation

/// Tracks all windows known to KiwiDesk.
///
/// Pure state container: no Accessibility calls. The event loop
/// feeds it snapshots; the layout engine reads from it.
public struct WindowManager: Sendable {
    private var windows: [WindowID: ManagedWindow] = [:]

    public init() {}

    /// All tracked windows, unordered.
    public var all: [ManagedWindow] {
        Array(windows.values)
    }

    public var count: Int {
        windows.count
    }

    public subscript(id: WindowID) -> ManagedWindow? {
        windows[id]
    }

    /// Inserts or replaces a window snapshot.
    public mutating func upsert(_ window: ManagedWindow) {
        windows[window.id] = window
    }

    /// Removes a window; returns the removed snapshot if present.
    @discardableResult
    public mutating func remove(
        _ id: WindowID
    ) -> ManagedWindow? {
        windows.removeValue(forKey: id)
    }

    /// Removes all windows belonging to a terminated app.
    /// Returns the IDs that were removed.
    @discardableResult
    public mutating func removeAll(pid: pid_t) -> [WindowID] {
        let ids = windows.values
            .filter { $0.pid == pid }
            .map(\.id)
        for id in ids {
            windows.removeValue(forKey: id)
        }
        return ids
    }

    /// Re-keys a tracked window in place: same snapshot, new id.
    /// Used when a native tab group's active tab changes (#308).
    /// The stored `ManagedWindow.id` is immutable, so the entry is
    /// rebuilt via `withID` (one mirror of the field list, guarded
    /// by `WindowRekeyParityTests`). No-op if `old` is absent.
    public mutating func rekey(_ old: WindowID, to new: WindowID) {
        guard let existing = windows.removeValue(forKey: old) else {
            return
        }
        windows[new] = existing.withID(new)
    }

    /// Windows belonging to one application.
    public func windows(pid: pid_t) -> [ManagedWindow] {
        windows.values.filter { $0.pid == pid }
    }

    public mutating func updateFrame(
        _ id: WindowID,
        frame: CGRect
    ) {
        windows[id]?.frame = frame
    }

    public mutating func updateTitle(
        _ id: WindowID,
        title: String
    ) {
        windows[id]?.title = title
    }

    /// Sets a window's sticky scope (#414/#445). Purely a state
    /// write — sticky has no detection source and no coupled
    /// invariant (unlike `setFloating`'s overlay clear below).
    public mutating func setSticky(
        _ id: WindowID,
        _ scope: StickyScope
    ) {
        windows[id]?.stickyScope = scope
    }

    /// Applies a re-detected native-fullscreen verdict — the
    /// fold target of `.windowFullscreenChanged`. Detection-owned
    /// like the overlay flag, but orthogonal to floating, so
    /// `setFloating` below deliberately does NOT touch it:
    /// clearing it there would desync the event loop's
    /// change-only `detectedFullscreen` cache and pin a stale
    /// verdict until the next fullscreen transition. The
    /// reconcile recheck is the single heal path.
    public mutating func setFullscreen(
        _ id: WindowID,
        _ fullscreen: Bool
    ) {
        windows[id]?.isFullscreen = fullscreen
    }

    public mutating func setFloating(
        _ id: WindowID,
        _ floating: Bool
    ) {
        windows[id]?.isFloating = floating
        // A transient overlay always floats, so untiling a window
        // must clear its overlay flag — the single mutation point
        // for `isFloating`, so every path (detection self-heal,
        // make_tiled, remembered-tiled restore) upholds the
        // invariant overlay ⟹ floating without re-asserting it
        // (#300). Only track-time init ever sets the flag true.
        if !floating {
            windows[id]?.isTransientOverlay = false
        }
    }
}
