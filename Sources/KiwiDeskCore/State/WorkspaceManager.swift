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

    /// Sets a space's layout mode; an actual mode *change* also
    /// clears the scrolling viewport offset (#66): a stale
    /// offset from a previous scrolling stint (different window
    /// count, different anchor) is not a meaningful "previous
    /// position" for a fresh one — re-entering scrolling should
    /// reseed from the anchor, not resume mid-scroll. A
    /// same-mode set must NOT clear: profile / GUI applies call
    /// this densely over all live spaces on every apply, and an
    /// unconditional clear would snap every scrolling viewport
    /// home whenever an unrelated setting is edited.
    public mutating func setMode(
        _ id: SpaceID,
        _ mode: LayoutMode
    ) {
        guard spaces[id]?.mode != mode else { return }
        spaces[id]?.mode = mode
        spaces[id]?.scrollOffset = nil
        // Track boundaries follow the same rule (#128): a
        // fresh track stint never resumes markers minted for a
        // different stint. Entering track seeds every window
        // as its own track (the dynamic default; a positive
        // cap merges the surplus at read time).
        spaces[id]?.trackWeights = [:]
        let seed =
            mode == .track
            ? Set(spaces[id]?.windows ?? []) : Set()
        spaces[id]?.trackBreaks = seed
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
        var seen: Set<SpaceID> = []
        // First occurrence wins — a duplicate id in `desired`
        // must not duplicate a space in the iteration order.
        let front = desired.filter {
            current.contains($0) && seen.insert($0).inserted
        }
        let rest = order.filter { !seen.contains($0) }
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

    /// Adds a window to a track-mode space per the track
    /// layout's `new_window` rule (#128), removing it from its
    /// old space. The track twin of `add(_:to:placement:)`;
    /// `isTiled` supplies the float knowledge the space does
    /// not hold.
    public mutating func add(
        _ window: WindowID,
        to id: SpaceID,
        trackRule: TrackParams.NewWindowTrack,
        trackPosition: SpawnPlacement,
        cap: Int,
        isTiled: (WindowID) -> Bool
    ) {
        remove(window)
        ensureSpace(id)
        spaces[id]?.insertIntoTrack(
            window,
            rule: trackRule,
            position: trackPosition,
            cap: cap,
            isTiled: isTiled
        )
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
