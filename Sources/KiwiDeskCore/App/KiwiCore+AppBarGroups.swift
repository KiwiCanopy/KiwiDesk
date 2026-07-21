import AppKit

/// Building a bar's items from a space's windows: the tiled
/// windows in order, with adjacent same-app runs optionally
/// collapsed into groups. Shared by the per-display driver
/// (`KiwiCore+AppBar`) and the drag reorder.
extension KiwiCore {
    /// The window whose App Bar item renders *focused* for
    /// `space`. On the **active** space this is the system
    /// frontmost (`lastFocused`), not the space's own `focused`
    /// slot: a tiled-sticky traveler holds the system focus but
    /// can never be the membership-guarded slot (#431), so
    /// `space.focused` would leave its item on the unfocused tier
    /// and never expand its group — the same fix the Space Bar
    /// already carries (#414). Every **inactive**-display space
    /// keeps its own remembered `focused`, which never holds the
    /// system focus. (The Space Bar reads raw `lastFocused`: its
    /// items are spaces, so a non-active space's group simply
    /// never contains it — no active-space guard needed there.)
    func appBarFocused(of space: Space) -> WindowID? {
        guard space.id == activeSpace?.id else {
            return space.focused
        }
        return state.workspaces.lastFocused ?? space.focused
    }

    /// The bar's items: the space's tiled windows in order,
    /// with adjacent same-app runs collapsed into one group
    /// while `grouping` is on. Same-app windows that are not
    /// adjacent stay separate items.
    ///
    /// The group holding the focused window renders *expanded*
    /// — its members become individual items, so after clicking
    /// a group (which focuses its first member) any member can
    /// be picked or dragged directly. Focus leaving the group
    /// collapses it again.
    func barGroups(
        in space: Space,
        grouping: Bool
    ) -> [[WindowID]] {
        let tiled = state.effectiveTiledMembers(
            of: space,
            activeSpace: activeSpace?.id
        )
        guard grouping else {
            return tiled.map { [$0] }
        }
        let names = tiled.map {
            state.windows[$0]?.appName ?? "?"
        }
        // Sticky windows stay individual items like on the
        // Space Bar (#414): merging a tiled-sticky traveler
        // into a same-app group would hide it behind an
        // aggregate count, and clicking the group would focus
        // its first member — possibly the traveler. Floating
        // never appears here (tiled list).
        let specials = tiled.map {
            state.windows[$0]?.isSticky == true
        }
        let runs = Self.adjacentRuns(
            of: names,
            specials: specials
        ).map {
            Array(tiled[$0])
        }
        return runs.flatMap { group -> [[WindowID]] in
            let focusedInside =
                appBarFocused(of: space).map(group.contains)
                ?? false
            return focusedInside && group.count > 1
                ? group.map { [$0] } : [group]
        }
    }

    /// Runs of equal adjacent values, with optional floating/sticky
    /// flags breaking runs into individual 1-window items (#414):
    /// ["Zed", "Zed", "Finder", "Zed"] ->
    /// [0..<2, 2..<3, 3..<4] — floating/sticky items do not merge.
    nonisolated static func adjacentRuns(
        of names: [String],
        specials: [Bool] = []
    ) -> [Range<Int>] {
        var runs: [Range<Int>] = []
        var start = 0
        for index in names.indices {
            let isLast = (index + 1 == names.count)
            let isSpecial = !specials.isEmpty && specials[index]
            let nextIsSpecial =
                !specials.isEmpty && !isLast && specials[index + 1]
            let nameChanges =
                !isLast && names[index + 1] != names[index]

            if isLast || isSpecial || nextIsSpecial || nameChanges {
                runs.append(start..<(index + 1))
                start = index + 1
            }
        }
        return runs
    }

    func barItem(
        for group: [WindowID],
        style: AppBarStyle
    ) -> AppBarOverlay.Item {
        let window = group.first.flatMap {
            state.windows[$0]
        }
        let name = window?.appName ?? "?"
        // Clicking a collapsed group focuses its first
        // member; the resulting re-render expands the group
        // into individual items (see barGroups).
        return AppBarOverlay.Item(
            id: group.first ?? WindowID(0),
            name: name,
            icon: window.flatMap {
                NSRunningApplication(
                    processIdentifier: $0.pid
                )?.icon
            },
            // Nil (source wants images / map still loading /
            // no glyph / font absent) falls back to the
            // native image in the item view.
            glyph: appFont.glyph(
                forAppName: name,
                source: style.iconSource
            ),
            count: group.count
        )
    }
}
