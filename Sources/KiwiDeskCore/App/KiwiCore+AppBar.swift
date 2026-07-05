import AppKit

/// Keeps the indicator bar in sync with the active space. Driven
/// from `retile()`, which already fires on every structural,
/// focus, mode, and settings change. Any layout that hosts a bar
/// (monocle, scrolling) drives the one shared overlay; the bar's
/// look is the global `AppBarStyle` overlaid by that layout's own
/// overrides.
extension KiwiCore {
    func updateAppBar() {
        let settings = tiler.settings
        guard let space = activeSpace,
            let host = barHost(for: space.mode),
            host.appBar.enabled,
            let screen = NSScreen.main ?? NSScreen.screens.first
        else {
            appBar.hide()
            return
        }
        let style = host.resolvedBar(global: settings.appBarStyle)
        let context = settings.context(
            bounds: GeometryUtils.axVisibleFrame(of: screen),
            space: space
        )
        let groups = barGroups(
            in: space,
            grouping: style.groupAdjacentWindows
        )
        guard !groups.isEmpty,
            let strip = host.barFrame(
                in: context.usable,
                global: settings.appBarStyle
            )
        else {
            appBar.hide()
            return
        }
        appBar.show(
            items: groups.map(barItem),
            activeIndex: groups.firstIndex { group in
                space.focused.map(group.contains) ?? false
            },
            strip: strip,
            style: style
        )
    }

    /// The bar-hosting layout for a space mode, or nil for modes
    /// that don't show a bar.
    func barHost(for mode: LayoutMode) -> AppBarHosting? {
        switch mode {
        case .monocle: return tiler.settings.monocle
        case .scrolling: return tiler.settings.scrolling
        default: return nil
        }
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
        let tiled = space.windows.filter {
            state.windows[$0]?.isFloating == false
        }
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

    private func barItem(
        for group: [WindowID]
    ) -> AppBarOverlay.Item {
        let window = group.first.flatMap {
            state.windows[$0]
        }
        // Clicking a collapsed group focuses its first
        // member; the resulting re-render expands the group
        // into individual items (see barGroups).
        return AppBarOverlay.Item(
            id: group.first ?? WindowID(0),
            name: window?.appName ?? "?",
            icon: window.flatMap {
                NSRunningApplication(
                    processIdentifier: $0.pid
                )?.icon
            },
            count: group.count
        )
    }

    /// Drag-and-drop reorder from the bar: moves the item at
    /// slot `from` (a single window or a whole group) to slot
    /// `to`, rewriting the tiled order in place — floating
    /// windows keep their positions in the flat array.
    func moveBarItem(from: Int, to: Int) {
        guard let space = activeSpace,
            let host = barHost(for: space.mode)
        else { return }
        let style = host.resolvedBar(
            global: tiler.settings.appBarStyle
        )
        var groups = barGroups(
            in: space,
            grouping: style.groupAdjacentWindows
        )
        guard from != to,
            groups.indices.contains(from),
            groups.indices.contains(to)
        else { return }
        let moved = groups.remove(at: from)
        groups.insert(moved, at: min(to, groups.count))
        var reordered = Array(groups.joined()).makeIterator()
        // Resolved before withSpace: reading `state` inside
        // its inout closure would violate exclusivity.
        let tiled = Set(
            space.windows.filter {
                state.windows[$0]?.isFloating == false
            }
        )
        state.workspaces.withSpace(space.id) { sp in
            sp.windows = sp.windows.map { id in
                tiled.contains(id)
                    ? (reordered.next() ?? id) : id
            }
        }
        retile()
    }
}
