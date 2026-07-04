import AppKit

/// Keeps the monocle indicator bar in sync with the active
/// space. Driven from `retile()`, which already fires on
/// every structural, focus, mode, and settings change.
extension KiwiCore {
    func updateMonocleBar() {
        let params = tiler.settings.monocle
        guard let space = activeSpace,
            space.mode == .monocle,
            params.bar.enabled,
            let screen = NSScreen.main
                ?? NSScreen.screens.first
        else {
            monocleBar.hide()
            return
        }
        let groups = monocleGroups(in: space)
        let context = tiler.settings.context(
            bounds: GeometryUtils.axVisibleFrame(of: screen),
            space: space
        )
        guard !groups.isEmpty,
            let strip = params.barFrame(in: context.usable)
        else {
            monocleBar.hide()
            return
        }
        monocleBar.show(
            items: groups.map {
                barItem(for: $0, focused: space.focused)
            },
            activeIndex: groups.firstIndex { group in
                space.focused.map(group.contains) ?? false
            },
            strip: strip,
            params: params
        )
    }

    /// The bar's items: the space's tiled windows in order,
    /// with adjacent same-app runs collapsed into one group
    /// while `bar.group_adjacent_windows` is on. Same-app
    /// windows that are not adjacent stay separate items.
    ///
    /// The group holding the focused window renders
    /// *expanded* — its members become individual items, so
    /// after clicking a group (which focuses its first
    /// member) any member can be picked or dragged directly.
    /// Focus leaving the group collapses it again.
    func monocleGroups(in space: Space) -> [[WindowID]] {
        let tiled = space.windows.filter {
            state.windows[$0]?.isFloating == false
        }
        let bar = tiler.settings.monocle.bar
        guard bar.groupAdjacentWindows else {
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
        for group: [WindowID],
        focused: WindowID?
    ) -> IndicatorBarOverlay.Item {
        let window = group.first.flatMap {
            state.windows[$0]
        }
        // Clicking a collapsed group focuses its first
        // member; the resulting re-render expands the group
        // into individual items (see monocleGroups).
        return IndicatorBarOverlay.Item(
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
    func moveMonocleItem(from: Int, to: Int) {
        guard let space = activeSpace,
            space.mode == .monocle
        else { return }
        var groups = monocleGroups(in: space)
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
