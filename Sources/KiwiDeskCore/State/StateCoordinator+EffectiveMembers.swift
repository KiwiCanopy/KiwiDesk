import Foundation

// MARK: - Effective space membership (#414/#415)
//
// A sticky window is a real member of exactly ONE space — its
// home (`Space.windows` holds it nowhere else). Presence on
// every space is DERIVED here, never stored: a tiled-sticky
// window is injected into the ACTIVE space's tiled member list
// at a position computed from its home-space position (#414
// v2), and the Space Bar's glyph membership travels alongside.

extension StateCoordinator {
    /// Ordered tiled members a space actually OWNS
    /// (`space.windows` minus floating and native-fullscreen)
    /// — no sticky injection. The derivation for anything that
    /// writes positions back into `space.windows` (the App Bar
    /// drag reorder), where an injected traveler with no local
    /// slot would overwrite a real window's slot (#414 v2).
    ///
    /// Native-fullscreen exemption (#670): the window keeps
    /// its slot in `space.windows` (fullscreen is not a
    /// destroy — the design ruling `FullscreenStateTests`
    /// pins), but macOS moved it to its own Space, so no
    /// layout pass, navigation step, or z-order raise may
    /// target it until it returns. The `.windowFullscreenChanged`
    /// retile re-places it on exit.
    public func localTiledMembers(
        of space: Space
    ) -> [WindowID] {
        space.windows.filter { id in
            guard let window = windows[id] else { return false }
            return !window.isFloating && !window.isFullscreen
        }
    }

    /// Ordered tiled members of a space for layout, navigation,
    /// and z-order — the single authority replacing the
    /// open-coded `space.windows.filter { !isFloating }` sites
    /// (#415).
    ///
    /// #414 v2: on the ACTIVE space this additionally injects
    /// every tiled-sticky window homed on another space, each
    /// inserted at an index derived from its position among its
    /// home space's own tiled members (clamped to the target
    /// list, insertion — never overwrite, never stored).
    /// Reordering a sticky on its HOME space therefore moves its
    /// derived slot everywhere for free; reordering it on a
    /// foreign space is a v2 non-goal (`Space.swap` membership
    /// guards no-op on a non-member). Inactive spaces stay pure
    /// local: only the space on screen tiles travelers.
    public func effectiveTiledMembers(
        of space: Space,
        activeSpace: SpaceID? = nil
    ) -> [WindowID] {
        let focused = activeSpace ?? workspaces.activeSpace
        // A local sticky that RENDERS on another space has
        // physically traveled away (#445: a global sticky follows
        // the focused display; a display sticky follows its home
        // monitor's shown space). Drop it from this space's layout
        // so its home monitor reserves no phantom slot to fight the
        // traveler frame on the render display. On the common
        // single-monitor / home-active path its render space IS
        // this space, so nothing is dropped.
        var members = localTiledMembers(of: space).filter { id in
            guard let window = windows[id], window.isSticky
            else { return true }
            return stickyRenderSpace(of: window, focused: focused)
                == space.id
        }
        // Ascending (index, id) order, each insertion offset by
        // the travelers already placed before it: earlier
        // travelers occupy slots ahead of later home indexes,
        // and the offset keeps the clamped (append) case in the
        // same ascending order — a reversed insertion inverted
        // ties whenever two travelers clamped to the end.
        for (placed, traveler)
            in tiledStickyTravelers(into: space, focused: focused)
            .enumerated()
        {
            members.insert(
                traveler.id,
                at: min(
                    traveler.homeIndex + placed,
                    members.count
                )
            )
        }
        return members
    }

    /// The single space a sticky window RENDERS on right now —
    /// where its one physical frame lands and its glyph shows
    /// (#445). A sticky window is a real member of one home space
    /// but is DERIVED onto others; with two scopes across several
    /// monitors it can only physically be one place, so this names
    /// it:
    ///
    /// - `.global`: the FOCUSED active space. One physical window
    ///   follows the display the user is on — injected there as a
    ///   traveler, or rendered in place when its home space IS the
    ///   focused one.
    /// - `.display`: the space currently shown on its HOME display
    ///   (`activeSpace(on:)`). It never leaves that monitor; a
    ///   cross-display `move_to_space` re-homes it first.
    ///
    /// Collapses to the focused active space when the home display
    /// is unresolvable (single monitor, early boot, unit tests) —
    /// there "one monitor" and "every monitor" coincide, so a
    /// display sticky behaves exactly like a global one.
    func stickyRenderSpace(
        of window: ManagedWindow,
        focused: SpaceID?
    ) -> SpaceID? {
        switch window.stickyScope {
        case .none:
            return nil
        case .global:
            return focused ?? workspaces.activeSpace
        case .display:
            guard let display = homeDisplay(of: window.id) else {
                return focused ?? workspaces.activeSpace
            }
            return workspaces.activeSpace(on: display)
        }
    }

    /// The display a window's HOME space is assigned to — the one
    /// primitive the "home display = display of home space"
    /// invariant (#445) rests on, shared so `stickyRenderSpace`,
    /// `stickyExemptFromStash`, and the move guard cannot drift on
    /// how it is computed. Each caller keeps its own fallback for
    /// the unresolvable (single-monitor / unassigned) case.
    func homeDisplay(of window: WindowID) -> DisplayID? {
        workspaces.space(of: window)
            .flatMap { workspaces.display(of: $0) }
    }

    /// Whether a sticky window is exempt from the inactive-space
    /// stash while `space` is being parked (#414/#445). A global
    /// sticky is always exempt — present on every monitor. A
    /// display sticky is exempt only on its OWN display's spaces:
    /// parking a space on ANOTHER display must not keep it visible
    /// there. Under the one-home-space invariant the window only
    /// ever appears in the stash loop on its home display, so this
    /// is exempt-in-practice; the display check states the
    /// invariant explicitly and stays correct if that ever shifts.
    /// Collapses to exempt when the home display is unresolvable
    /// (single monitor), where display and global sticky coincide.
    func stickyExemptFromStash(
        _ window: ManagedWindow,
        onSpace space: SpaceID
    ) -> Bool {
        switch window.stickyScope {
        case .none:
            return false
        case .global:
            return true
        case .display:
            guard let homeDisplay = homeDisplay(of: window.id)
            else { return true }
            return workspaces.display(of: space) == homeDisplay
        }
    }

    /// The window a focus-driven surface should treat as focused
    /// on `space` — the target a Scrolling space pans to, a
    /// Monocle space raises on top, and the App Bar highlights
    /// (`KiwiCore.appBarFocused`). Normally its own `focused`
    /// slot, except when
    /// a tiled-sticky traveler is the frontmost window
    /// (`lastFocused`) and can never BE that slot (#431). A
    /// traveler is injected into the active space's row (present
    /// in `tiled`) yet is a member only of its home space, so
    /// `WorkspaceManager.focus`'s membership guard keeps
    /// `space.focused` off it; without this the layout cannot
    /// surface it — clicking its bar item, or navigating to it,
    /// would leave it off-screen (Scrolling) or buried (Monocle).
    ///
    /// `lastFocused` is a **global** field, so the anchor tracks
    /// the last-focused window across the whole workspace: it
    /// yields the traveler until any real member is next focused,
    /// not the instant a space is switched (a bare switch fires no
    /// focus event). An inactive space injects no travelers
    /// (`tiled` is local-only) so it always yields its own focus.
    ///
    /// A **floating** sticky traveler is never in `tiled`, so it
    /// gets its own membership test (#416): when `lastFocused` is
    /// a floating sticky that RENDERS on this space, it is the
    /// window under the user's eyes — resolving past it to the
    /// stale local slot made same-app implicit-focused verbs
    /// (`toggle_sticky` pressed while looking at the sticky)
    /// silently mutate the wrong window, and cross-app ones fail
    /// the #292 pid check. The render space resolves against the
    /// REAL active space (`focused: nil`), so an inactive space
    /// keeps yielding its own focus — matching the one-arg
    /// overload, whose traveler injection likewise uses the real
    /// active space.
    ///
    /// - Parameters:
    ///   - space: the space whose surface target is wanted.
    ///   - tiled: the space's `effectiveTiledMembers`, passed in
    ///     so the caller's already-computed list is reused rather
    ///     than recomputed.
    /// - Returns: the traveler to surface, or `space.focused` when
    ///   no frontmost traveler applies (may itself be `nil`).
    public func focusAnchor(
        of space: Space,
        tiled: [WindowID]
    ) -> WindowID? {
        guard let last = workspaces.lastFocused,
            !space.windows.contains(last)
        else { return space.focused }
        if tiled.contains(last) { return last }
        if let window = windows[last], window.isSticky,
            window.isFloating,
            stickyRenderSpace(of: window, focused: nil)
                == space.id
        {
            return last
        }
        return space.focused
    }

    /// `focusAnchor` computing its own `tiled` — for the many
    /// focused-command bodies that don't already hold the space's
    /// `effectiveTiledMembers`. Travelers are injected against
    /// the REAL active space (not the queried space as if it
    /// were active, #416 review): a traveler physically renders
    /// on one space, so an inactive space injects none and
    /// collapses to `space.focused` — the same notion of
    /// "active" the floating-sticky test uses, keeping the two
    /// traveler branches in agreement.
    public func focusAnchor(of space: Space) -> WindowID? {
        focusAnchor(
            of: space,
            tiled: effectiveTiledMembers(of: space)
        )
    }

    /// The Space Bar's membership for a space: on the current
    /// space, sticky windows homed elsewhere travel in — tiled
    /// travelers at their injected layout position (so the bar
    /// order matches the tiles on screen, #414 v2), floating
    /// travelers appended id-sorted (they have no slot); on any
    /// other space, its own sticky windows are pruned so each
    /// glyph shows in exactly one place. Two client classes:
    /// presentation (the bars) and, filtered to floats, the
    /// float tier of directional focus
    /// (`floatingFocusCandidates`, #488) — layout/z-order keep
    /// using `effectiveTiledMembers`.
    public func effectiveMembers(
        of space: Space,
        activeSpace: SpaceID? = nil
    ) -> [WindowID] {
        let focused = activeSpace ?? workspaces.activeSpace
        let injected = effectiveTiledMembers(
            of: space,
            activeSpace: focused
        )
        // Merge: local windows keep their flat-array positions
        // (floating included); each tiled traveler lands before
        // the local tiled member that follows it in the injected
        // order. Locals appear in `injected` in their original
        // relative order, so a single cursor suffices. A local
        // sticky that renders on ANOTHER space (#445) is skipped —
        // its glyph shows once, where it renders — and it is absent
        // from `injected` too (dropped there), so the cursor stays
        // aligned. This subsumes the old "prune own sticky on a
        // non-active space" branch and additionally KEEPS a sticky
        // that renders on a secondary display's shown space.
        var result: [WindowID] = []
        var next = 0
        for id in space.windows {
            if let window = windows[id], window.isSticky,
                stickyRenderSpace(of: window, focused: focused)
                    != space.id
            {
                continue
            }
            // Fullscreen rides the float branch (#670): it is
            // absent from `injected` (layout-exempt), so the
            // tiled cursor below would drain past it — append
            // in place instead, keeping its glyph and the
            // cursor aligned.
            guard let window = windows[id],
                !window.isFloating, !window.isFullscreen
            else {
                result.append(id)
                continue
            }
            while next < injected.count, injected[next] != id {
                result.append(injected[next])
                next += 1
            }
            result.append(id)
            if next < injected.count { next += 1 }
        }
        result.append(contentsOf: injected[next...])
        let floating = windows.all
            .filter {
                $0.isSticky && $0.isFloating
                    && !space.windows.contains($0.id)
                    && stickyRenderSpace(of: $0, focused: focused)
                        == space.id
            }
            .map(\.id)
            .sorted { $0.raw < $1.raw }
        return result + floating
    }

    /// Tiled-sticky windows homed on a space OTHER than
    /// `space`, paired with their derived injection index — the
    /// window's position among its home space's own tiled
    /// members. Sorted by (index, id) so multiple stickies
    /// insert in a stable order regardless of dictionary
    /// ordering.
    private func tiledStickyTravelers(
        into space: Space,
        focused: SpaceID?
    ) -> [(id: WindowID, homeIndex: Int)] {
        windows.all
            .filter {
                // A fullscreen sticky travels nowhere (#670);
                // the `firstIndex` below would drop it anyway
                // (it has no local tiled slot), stated here so
                // the exemption is deliberate, not incidental.
                $0.isSticky && !$0.isFloating && !$0.isFullscreen
                    && !space.windows.contains($0.id)
                    && stickyRenderSpace(of: $0, focused: focused)
                        == space.id
            }
            .compactMap { window -> (WindowID, Int)? in
                guard
                    let homeID = workspaces.space(of: window.id),
                    let home = workspaces[homeID],
                    let index = localTiledMembers(of: home)
                        .firstIndex(of: window.id)
                else { return nil }
                return (window.id, index)
            }
            .sorted { ($0.1, $0.0.raw) < ($1.1, $1.0.raw) }
    }
}
