import Foundation

// Sticky windows belong to one home space; presence on other spaces is derived
// (#414, #415).

extension StateCoordinator {
    /// Ordered tiled members a space owns (`space.windows` minus floating and
    /// native-fullscreen, #414 v2). Fullscreen keeps its slot but leaves
    /// tiling until return (#670, `FullscreenStateTests`).
    public func localTiledMembers(
        of space: Space
    ) -> [WindowID] {
        space.windows.filter { id in
            guard let window = windows[id] else { return false }
            return !window.isFloating && !window.isFullscreen
        }
    }

    /// Ordered tiled members for layout, navigation, and z-order (#415).
    /// Injects tiled-sticky travelers on active space at home-derived indices
    /// (#414 v2, #445).
    public func effectiveTiledMembers(
        of space: Space,
        activeSpace: SpaceID? = nil
    ) -> [WindowID] {
        let focused = activeSpace ?? workspaces.activeSpace
        // Local sticky rendering elsewhere drops from local layout (#445).
        var members = localTiledMembers(of: space).filter { id in
            guard let window = windows[id], window.isSticky
            else { return true }
            return stickyRenderSpace(of: window, focused: focused)
                == space.id
        }
        // Offset by already-placed travelers to preserve ascending order.
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

    /// The single space a sticky window renders on currently (#445).
    /// Global follows focused space; display follows home monitor's active
    /// space.
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

    /// Display assigned to a window's home space (#445).
    func homeDisplay(of window: WindowID) -> DisplayID? {
        workspaces.space(of: window)
            .flatMap { workspaces.display(of: $0) }
    }

    /// Whether sticky window is exempt from inactive stash on `space`
    /// (#414, #445).
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

    /// The window a focus-driven surface should treat as focused on `space`,
    /// including frontmost sticky travelers (#431, #416, #292).
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

    /// Variant of `focusAnchor` computing its own `tiled` list (#416).
    public func focusAnchor(of space: Space) -> WindowID? {
        focusAnchor(
            of: space,
            tiled: effectiveTiledMembers(of: space)
        )
    }

    /// Space Bar membership including injected travelers and pruned stickies
    /// (#414 v2, #488, #445). Fullscreen stickies stay home (#670).
    public func effectiveMembers(
        of space: Space,
        activeSpace: SpaceID? = nil
    ) -> [WindowID] {
        let focused = activeSpace ?? workspaces.activeSpace
        let injected = effectiveTiledMembers(
            of: space,
            activeSpace: focused
        )
        var result: [WindowID] = []
        var next = 0
        for id in space.windows {
            // Fullscreen stickies stay home (#670).
            if let window = windows[id], window.isFullscreen {
                result.append(id)
                continue
            }
            if let window = windows[id], window.isSticky,
                stickyRenderSpace(of: window, focused: focused)
                    != space.id
            {
                continue
            }
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
            .filter {
                $0.isSticky && $0.isFloating && !$0.isFullscreen
                    && !space.windows.contains($0.id)
                    && stickyRenderSpace(of: $0, focused: focused)
                        == space.id
            }
            .map(\.id)
            .sorted { $0.raw < $1.raw }
        return result + floating
    }

    /// Tiled-sticky windows homed elsewhere with derived home index (#670).
    private func tiledStickyTravelers(
        into space: Space,
        focused: SpaceID?
    ) -> [(id: WindowID, homeIndex: Int)] {
        windows.all
            .filter {
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
