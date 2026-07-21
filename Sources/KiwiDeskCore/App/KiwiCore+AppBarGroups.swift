import AppKit

/// Building a bar's items from a space's windows: the tiled
/// windows in order, with adjacent same-app runs optionally
/// collapsed into groups. Shared by the per-display driver
/// (`KiwiCore+AppBar`) and the drag reorder.
extension KiwiCore {
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
        let runs = Self.adjacentRuns(of: names).map {
            Array(tiled[$0])
        }
        return runs.flatMap { group -> [[WindowID]] in
            let focusedInside =
                space.focused.map(group.contains) ?? false
            return focusedInside && group.count > 1
                ? group.map { [$0] } : [group]
        }
    }

    /// Runs of equal adjacent values:
    /// ["Zed", "Zed", "Finder", "Zed"] ->
    /// [0..<2, 2..<3, 3..<4] — the trailing Zed is not next
    /// to the first two, so it stays its own run.
    nonisolated static func adjacentRuns(
        of names: [String]
    ) -> [Range<Int>] {
        var runs: [Range<Int>] = []
        var start = 0
        for index in names.indices
        where index + 1 == names.count
            || names[index + 1] != names[index]
        {
            runs.append(start..<(index + 1))
            start = index + 1
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
