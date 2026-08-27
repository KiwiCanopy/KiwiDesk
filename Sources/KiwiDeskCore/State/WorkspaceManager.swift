import Foundation

/// Manages Spaces and their display assignment.
///
/// Pure state container: window-to-space membership lives here as
/// flat arrays inside each `Space`. A window belongs to at most one
/// space at a time.
public struct WorkspaceManager: Sendable {
    private var spaces: [SpaceID: Space] = [:]
    /// Creation order, used for deterministic iteration.
    /// Internal (not private) with the three display maps
    /// below: the `+Displays` split reads them cross-file.
    /// Writes stay inside the two `WorkspaceManager*` files —
    /// `WorkspaceMapSealTests` pins the two scannable names
    /// and states why these two are not.
    var order: [SpaceID] = []
    var displays: [DisplayID: Display] = [:]
    var spaceDisplay: [SpaceID: DisplayID] = [:]
    /// The space shown on the FOCUSED display — the one the user
    /// is currently acting on. Every command that means "the
    /// current space" reads this. On a single monitor it is the
    /// whole story; with several, the other displays' shown
    /// spaces live in `secondaryShown`.
    public private(set) var activeSpace: SpaceID?

    /// The space shown on each display OTHER than the focused
    /// one (multi-monitor, #multi-monitor). AeroSpace's
    /// `screenPointToVisibleWorkspace` minus the focused entry:
    /// we keep the focused display's space in `activeSpace`, so
    /// the invariant is that `display(of: activeSpace)` is never
    /// a key here. A display absent from the map falls back to
    /// its first-assigned space, so a freshly attached monitor
    /// needs no explicit seeding — only an explicit switch away
    /// from that default records an entry. Every non-focused
    /// display's shown space is thus `activeSpace(on:)`.
    /// Internal like `order`: the `+Displays` split writes it.
    var secondaryShown: [DisplayID: SpaceID] = [:]

    /// The window holding the SYSTEM focus, across spaces —
    /// every focus write lands here (`focus(_:in:)` is the one
    /// write path). Distinct from a space's own `focused`,
    /// which is just that space's last-focused member: a
    /// sticky window focused from a foreign space (#414) makes
    /// the two disagree, and surfaces that accent "the focused
    /// window" (the Space Bar) must follow this one.
    public private(set) var lastFocused: WindowID?

    /// The window focused immediately BEFORE `lastFocused` — a
    /// one-deep history, not a stack. Read by the destroy fold's
    /// close-return pick (validated there against current state:
    /// alive, same space, surfaceable); deliberately never a
    /// deeper walk-back — invisible, self-reordering history is
    /// what the repeat-press-cycling ruling rejected, and one
    /// visible step back is the whole close-return promise
    /// (`docs/design-decisions.md` ▸ Close-return focus).
    public private(set) var focusReturnCandidate: WindowID?

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
        _ mode: LayoutMode,
        trackSeed: Set<WindowID>? = nil
    ) {
        guard spaces[id]?.mode != mode else { return }
        spaces[id]?.mode = mode
        spaces[id]?.scrollRest = nil
        // The session resize layer (#458) is a stint value like
        // the offset: a fresh mode stint reseeds from config.
        spaces[id]?.sessionRatios = SessionRatios()
        // Track boundaries follow the same rule (#128). Entering
        // track uses the caller's `trackSeed` (fill-then-spill
        // packing, #437) or seeds every window as its own track.
        spaces[id]?.trackWeights = [:]
        let seed: Set<WindowID> =
            mode == .track
            ? (trackSeed ?? Set(spaces[id]?.windows ?? []))
            : []
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

    /// Makes `id` the shown space on its display and moves focus
    /// to that display. If `id` lives on a DIFFERENT display than
    /// the currently focused one, the previously focused display
    /// keeps showing its space (parked in `secondaryShown`) — it
    /// is not stashed. On one monitor (or before displays are
    /// assigned) this reduces to the old behavior: replace the
    /// single `activeSpace`.
    public mutating func activate(_ id: SpaceID) {
        ensureSpace(id)
        let newDisplay = spaceDisplay[id]
        let oldDisplay = activeSpace.flatMap { spaceDisplay[$0] }
        if let newDisplay, newDisplay != oldDisplay {
            // Focus is moving to another display. Preserve the
            // display we're leaving so its space stays visible.
            if let oldDisplay, let old = activeSpace {
                secondaryShown[oldDisplay] = old
            }
            // The newly focused display's space is now the
            // authoritative `activeSpace`, not a secondary entry.
            secondaryShown[newDisplay] = nil
        }
        activeSpace = id
    }

    /// The space shown on `display`: the focused `activeSpace`
    /// when that space is assigned to this display, else an
    /// explicit `secondaryShown` pick, else the first space
    /// assigned to it (creation order). Nil when nothing is
    /// assigned. This is the single truth the tiler lays out per
    /// display and the bars read (superseding `currentSpace`).
    public func activeSpace(on display: DisplayID) -> SpaceID? {
        if let active = activeSpace, spaceDisplay[active] == display {
            return active
        }
        // Self-healing: a `secondaryShown` pick counts only while
        // that space still lives on THIS display. A reassignment
        // (profile apply, topology change) can leave the entry
        // stale — pointing at a space now on another display — and
        // honoring it would lay the same space on two screens. A
        // stale entry is ignored, falling back to the first
        // assigned space, so the read path stays correct even if a
        // writer forgot to prune.
        if let shown = secondaryShown[display],
            spaceDisplay[shown] == display
        {
            return shown
        }
        return spaces(on: display).first
    }

    /// Every space currently visible on some display — the
    /// focused `activeSpace` plus each other display's shown
    /// space. Drives `stashInactive`: a space in this set is
    /// laid out in place on its display; every space outside it
    /// is parked in a corner. With no displays known yet, this
    /// is just `{activeSpace}`, so the single-monitor path is
    /// unchanged.
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

    /// Removes a space and forgets its display assignment. Any
    /// windows still in it are dropped, so callers that must keep
    /// them move them out first (`add(_:to:)`). The active space
    /// falls back to the first remaining space when removed.
    public mutating func removeSpace(_ id: SpaceID) {
        spaces[id] = nil
        order.removeAll { $0 == id }
        spaceDisplay[id] = nil
        secondaryShown = secondaryShown.filter { $0.value != id }
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

    /// Adds a window to a track-mode space per `new_window` (#128,
    /// #437), removing it from its old space; the track twin of
    /// `add(_:to:placement:)`. `isTiled` supplies float knowledge.
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

    /// Removes a window from whatever space contains it.
    public mutating func remove(_ window: WindowID) {
        if lastFocused == window { lastFocused = nil }
        if focusReturnCandidate == window { focusReturnCandidate = nil }
        guard let id = space(of: window) else { return }
        spaces[id]?.remove(window)
    }

    /// Re-keys a window in its space, preserving slot and focus
    /// (#308). No-op if `old` is in no space.
    public mutating func rekey(_ old: WindowID, to new: WindowID) {
        if lastFocused == old { lastFocused = new }
        // The close-return candidate must follow a native-tab
        // rekey like `lastFocused` does, or every tab switch
        // silently kills it.
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

    /// Mutates one space in place (array reordering etc.).
    public mutating func withSpace(
        _ id: SpaceID,
        _ body: (inout Space) -> Void
    ) {
        guard var space = spaces[id] else { return }
        body(&space)
        spaces[id] = space
    }

}
