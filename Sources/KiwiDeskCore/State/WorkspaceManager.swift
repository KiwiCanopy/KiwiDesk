import Foundation

/// Manages virtual workspaces and their display assignment.
///
/// Pure state container: window-to-space membership lives here as
/// flat arrays inside each `Space`. A window belongs to at most one
/// space at a time.
public struct WorkspaceManager: Sendable {
    private var spaces: [SpaceID: Space] = [:]
    /// Creation order, used for deterministic iteration.
    private var order: [SpaceID] = []
    private var displays: [DisplayID: Display] = [:]
    private var spaceDisplay: [SpaceID: DisplayID] = [:]
    public private(set) var activeSpace: SpaceID?

    public init() {}

    // MARK: - Spaces

    public var allSpaces: [Space] {
        order.compactMap { spaces[$0] }
    }

    public subscript(id: SpaceID) -> Space? {
        spaces[id]
    }

    /// Returns the space, creating it on first use.
    @discardableResult
    public mutating func ensureSpace(
        _ id: SpaceID,
        mode: LayoutMode = .bsp
    ) -> Space {
        if let existing = spaces[id] {
            return existing
        }
        let space = Space(id: id, mode: mode)
        spaces[id] = space
        order.append(id)
        if activeSpace == nil {
            activeSpace = id
        }
        return space
    }

    public mutating func setMode(
        _ id: SpaceID,
        _ mode: LayoutMode
    ) {
        spaces[id]?.mode = mode
    }

    /// Reorders the iteration order to follow `desired` for
    /// spaces present in both; spaces not mentioned keep their
    /// relative order, appended after. `ensureSpace` never
    /// reorders an existing space, so profile application calls
    /// this to reconcile creation order with the stored display
    /// order (#75/#55) — both profile-save paths then capture
    /// ONE order representation.
    public mutating func reorder(matching desired: [SpaceID]) {
        let current = Set(order)
        let front = desired.filter { current.contains($0) }
        let frontSet = Set(front)
        let rest = order.filter { !frontSet.contains($0) }
        order = front + rest
    }

    public mutating func activate(_ id: SpaceID) {
        ensureSpace(id)
        activeSpace = id
    }

    /// Removes a space and forgets its display assignment. Any
    /// windows still in it are dropped, so callers that must keep
    /// them move them out first (`add(_:to:)`). The active space
    /// falls back to the first remaining space when removed.
    public mutating func removeSpace(_ id: SpaceID) {
        spaces[id] = nil
        order.removeAll { $0 == id }
        spaceDisplay[id] = nil
        if activeSpace == id {
            activeSpace = order.first
        }
    }

    // MARK: - Window membership

    /// The space currently containing the window, if any.
    public func space(of window: WindowID) -> SpaceID? {
        order.first { spaces[$0]?.windows.contains(window) == true }
    }

    /// Adds a window to a space, removing it from its old
    /// space. With an anchor, the window is inserted right
    /// after it (new windows split the focused window).
    public mutating func add(
        _ window: WindowID,
        to id: SpaceID,
        after anchor: WindowID? = nil
    ) {
        remove(window)
        ensureSpace(id)
        spaces[id]?.insert(window, after: anchor)
    }

    /// Adds a window to a space per the layout's spawn
    /// placement rule (`new_window_placement`), removing it
    /// from its old space.
    public mutating func add(
        _ window: WindowID,
        to id: SpaceID,
        placement: SpawnPlacement
    ) {
        remove(window)
        ensureSpace(id)
        spaces[id]?.insert(window, placement: placement)
    }

    /// Removes a window from whatever space contains it.
    public mutating func remove(_ window: WindowID) {
        guard let id = space(of: window) else { return }
        spaces[id]?.remove(window)
    }

    public mutating func focus(
        _ window: WindowID,
        in id: SpaceID
    ) {
        guard spaces[id]?.windows.contains(window) == true else {
            return
        }
        spaces[id]?.focused = window
    }

    /// Mutates one space in place (array reordering etc.).
    public mutating func withSpace(
        _ id: SpaceID,
        _ body: (inout Space) -> Void
    ) {
        guard var space = spaces[id] else { return }
        body(&space)
        spaces[id] = space
    }

    // MARK: - Displays

    public var allDisplays: [Display] {
        Array(displays.values)
    }

    public mutating func upsertDisplay(_ display: Display) {
        displays[display.id] = display
    }

    @discardableResult
    public mutating func removeDisplay(
        _ id: DisplayID
    ) -> Display? {
        for (space, display) in spaceDisplay where display == id {
            spaceDisplay[space] = nil
        }
        return displays.removeValue(forKey: id)
    }

    public mutating func assign(
        _ space: SpaceID,
        to display: DisplayID
    ) {
        ensureSpace(space)
        spaceDisplay[space] = display
    }

    public func display(of space: SpaceID) -> DisplayID? {
        spaceDisplay[space]
    }

    /// Spaces assigned to one display, in creation order.
    public func spaces(on display: DisplayID) -> [SpaceID] {
        order.filter { spaceDisplay[$0] == display }
    }

    /// The space a display currently shows: the globally active
    /// space when it is assigned to this display, otherwise the
    /// first space assigned to it (creation order). Nil when no
    /// space is assigned. Drives the per-display app bar (#16);
    /// the composed layouts give each secondary display exactly
    /// one space, so the first-assigned fallback is the visible
    /// one there and the active space covers the main display.
    public func currentSpace(on display: DisplayID) -> SpaceID? {
        if let active = activeSpace, spaceDisplay[active] == display {
            return active
        }
        return spaces(on: display).first
    }
}
