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
    /// (`space.windows` minus floating) — no sticky injection.
    /// The derivation for anything that writes positions back
    /// into `space.windows` (the App Bar drag reorder), where
    /// an injected traveler with no local slot would overwrite
    /// a real window's slot (#414 v2).
    public func localTiledMembers(
        of space: Space
    ) -> [WindowID] {
        space.windows.filter { windows[$0]?.isFloating == false }
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
        var members = localTiledMembers(of: space)
        let activeID = activeSpace ?? workspaces.activeSpace
        guard space.id == activeID else { return members }
        // Ascending (index, id) order, each insertion offset by
        // the travelers already placed before it: earlier
        // travelers occupy slots ahead of later home indexes,
        // and the offset keeps the clamped (append) case in the
        // same ascending order — a reversed insertion inverted
        // ties whenever two travelers clamped to the end.
        for (placed, traveler)
            in tiledStickyTravelers(into: space).enumerated()
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

    /// The Space Bar's membership for a space: on the current
    /// space, sticky windows homed elsewhere travel in — tiled
    /// travelers at their injected layout position (so the bar
    /// order matches the tiles on screen, #414 v2), floating
    /// travelers appended id-sorted (they have no slot); on any
    /// other space, its own sticky windows are pruned so each
    /// glyph shows in exactly one place. Presentation-only —
    /// layout/nav use `effectiveTiledMembers`.
    public func effectiveMembers(
        of space: Space,
        activeSpace: SpaceID? = nil
    ) -> [WindowID] {
        let activeID = activeSpace ?? workspaces.activeSpace
        guard space.id == activeID else {
            return space.windows.filter { id in
                windows[id]?.isSticky != true
            }
        }
        let injected = effectiveTiledMembers(
            of: space,
            activeSpace: activeID
        )
        // Merge: local windows keep their flat-array positions
        // (floating included); each tiled traveler lands before
        // the local tiled member that follows it in the injected
        // order. Locals appear in `injected` in their original
        // relative order, so a single cursor suffices.
        var result: [WindowID] = []
        var next = 0
        for id in space.windows {
            guard windows[id]?.isFloating == false else {
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
            .filter { $0.isSticky && $0.isFloating }
            .map(\.id)
            .filter { !space.windows.contains($0) }
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
        into space: Space
    ) -> [(id: WindowID, homeIndex: Int)] {
        windows.all
            .filter {
                $0.isSticky && !$0.isFloating
                    && !space.windows.contains($0.id)
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
