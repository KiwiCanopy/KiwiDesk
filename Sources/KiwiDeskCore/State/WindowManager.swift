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

    /// Re-keys tracked window with new ID on tab switch
    /// (`WindowRekeyParityTests`, #308).
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

    /// Sets sticky scope on window (`StickyScope`, #414, #445).
    public mutating func setSticky(
        _ id: WindowID,
        _ scope: StickyScope
    ) {
        windows[id]?.stickyScope = scope
    }

    /// Sets native fullscreen state for window (`.windowFullscreenChanged`).
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
        // Untiling clears transient overlay flag to uphold invariant (#300).
        if !floating {
            windows[id]?.isTransientOverlay = false
        }
    }
}
