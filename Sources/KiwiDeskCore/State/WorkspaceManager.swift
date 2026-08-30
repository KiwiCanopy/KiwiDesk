import Foundation

/// Manages Spaces and their display assignment. Flat window arrays per space.
public struct WorkspaceManager: Sendable {
    private var spaces: [SpaceID: Space] = [:]
    /// Creation order; `WorkspaceMapSealTests` pins cross-file internal
    /// access.
    var order: [SpaceID] = []
    var displays: [DisplayID: Display] = [:]
    var spaceDisplay: [SpaceID: DisplayID] = [:]
    /// Space shown on currently focused display.
    public private(set) var activeSpace: SpaceID?

    /// Spaces shown on non-focused displays (#multi-monitor). The
    /// invariant: `display(of: activeSpace)` is never a key here;
    /// a display absent from the map falls back to its
    /// first-assigned space.
    var secondaryShown: [DisplayID: SpaceID] = [:]

    /// Window holding system-wide focus (#414).
    public private(set) var lastFocused: WindowID?

    /// The window focused immediately before `lastFocused` — a
    /// one-deep history, deliberately never a deeper walk-back:
    /// invisible self-reordering history is what the
    /// repeat-press-cycling ruling rejected, and one visible step
    /// back is the whole close-return promise
    /// (design-decisions ▸ Close-return focus).
    public private(set) var focusReturnCandidate: WindowID?

    public init() {}

    public var allSpaces: [Space] {
        order.compactMap { spaces[$0] }
    }

    public subscript(id: SpaceID) -> Space? {
        spaces[id]
    }

    /// Returns space, creating it on first use.
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

    /// Sets layout mode; an actual mode CHANGE clears the viewport
    /// offset and stint state (#66, #458, #128, #437). A same-mode
    /// set must NOT clear: profile/GUI applies call this densely
    /// over all live spaces, and an unconditional clear would snap
    /// every scrolling viewport home on any unrelated edit.
    public mutating func setMode(
        _ id: SpaceID,
        _ mode: LayoutMode,
        trackSeed: Set<WindowID>? = nil
    ) {
        guard spaces[id]?.mode != mode else { return }
        spaces[id]?.mode = mode
        spaces[id]?.scrollRest = nil
        spaces[id]?.sessionRatios = SessionRatios()
        spaces[id]?.trackWeights = [:]
        let seed: Set<WindowID> =
            mode == .track
            ? (trackSeed ?? Set(spaces[id]?.windows ?? []))
            : []
        spaces[id]?.trackBreaks = seed
    }

    /// Reorders iteration order to match desired order (#75, #55).
    public mutating func reorder(matching desired: [SpaceID]) {
        let current = Set(order)
        var seen: Set<SpaceID> = []
        let front = desired.filter {
            current.contains($0) && seen.insert($0).inserted
        }
        let rest = order.filter { !seen.contains($0) }
        order = front + rest
    }

    /// Activates space on its display and shifts display focus.
    public mutating func activate(_ id: SpaceID) {
        ensureSpace(id)
        let newDisplay = spaceDisplay[id]
        let oldDisplay = activeSpace.flatMap { spaceDisplay[$0] }
        if let newDisplay, newDisplay != oldDisplay {
            if let oldDisplay, let old = activeSpace {
                secondaryShown[oldDisplay] = old
            }
            secondaryShown[newDisplay] = nil
        }
        activeSpace = id
    }

    /// Active space shown on specified display.
    public func activeSpace(on display: DisplayID) -> SpaceID? {
        if let active = activeSpace, spaceDisplay[active] == display {
            return active
        }
        // Self-healing: a pick counts only while that space still
        // lives on THIS display — a stale entry would lay one
        // space on two screens, so it is ignored rather than
        // honored.
        if let shown = secondaryShown[display],
            spaceDisplay[shown] == display
        {
            return shown
        }
        return spaces(on: display).first
    }

    /// All spaces currently visible across displays.
    public var visibleSpaces: Set<SpaceID> {
        var result: Set<SpaceID> = []
        if let active = activeSpace { result.insert(active) }
        for display in displays.keys {
            if let shown = activeSpace(on: display) {
                result.insert(shown)
            }
        }
        return result
    }

    /// Removes space and clears display assignments.
    public mutating func removeSpace(_ id: SpaceID) {
        spaces[id] = nil
        order.removeAll { $0 == id }
        spaceDisplay[id] = nil
        secondaryShown = secondaryShown.filter { $0.value != id }
        if activeSpace == id {
            activeSpace = order.first
        }
    }

    /// Space containing window, if any.
    public func space(of window: WindowID) -> SpaceID? {
        order.first { spaces[$0]?.windows.contains(window) == true }
    }

    /// Adds window after anchor or at end.
    public mutating func add(
        _ window: WindowID,
        to id: SpaceID,
        after anchor: WindowID? = nil
    ) {
        remove(window)
        ensureSpace(id)
        spaces[id]?.insert(window, after: anchor)
    }

    /// Adds window according to layout spawn placement policy.
    public mutating func add(
        _ window: WindowID,
        to id: SpaceID,
        placement: SpawnPlacement
    ) {
        remove(window)
        ensureSpace(id)
        spaces[id]?.insert(window, placement: placement)
    }

    /// Adds window to track layout (#128, #437).
    public mutating func add(
        _ window: WindowID,
        to id: SpaceID,
        trackRule: TrackParams.NewWindowTrack,
        trackPosition: SpawnPlacement,
        spillCapacity: Int?,
        trackCap: Int,
        isTiled: (WindowID) -> Bool
    ) {
        remove(window)
        ensureSpace(id)
        spaces[id]?.insertIntoTrack(
            window,
            rule: trackRule,
            position: trackPosition,
            spillCapacity: spillCapacity,
            trackCap: trackCap,
            isTiled: isTiled
        )
    }

    /// Removes window from containing space and clears focus trackers.
    public mutating func remove(_ window: WindowID) {
        if lastFocused == window { lastFocused = nil }
        if focusReturnCandidate == window { focusReturnCandidate = nil }
        guard let id = space(of: window) else { return }
        spaces[id]?.remove(window)
    }

    /// Re-keys window ID preserving slot and focus (#308).
    public mutating func rekey(_ old: WindowID, to new: WindowID) {
        if lastFocused == old { lastFocused = new }
        // The candidate follows a native-tab rekey like
        // `lastFocused`, or every tab switch silently kills it.
        if focusReturnCandidate == old { focusReturnCandidate = new }
        guard let id = space(of: old) else { return }
        spaces[id]?.rekey(old, to: new)
    }

    public mutating func focus(
        _ window: WindowID,
        in id: SpaceID
    ) {
        guard spaces[id]?.windows.contains(window) == true else {
            return
        }
        // A re-focus of the already-focused window must not
        // collapse the history to itself.
        if lastFocused != window {
            focusReturnCandidate = lastFocused
        }
        spaces[id]?.focused = window
        lastFocused = window
    }

    /// Mutates space in place.
    public mutating func withSpace(
        _ id: SpaceID,
        _ body: (inout Space) -> Void
    ) {
        guard var space = spaces[id] else { return }
        body(&space)
        spaces[id] = space
    }
}
