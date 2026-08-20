import AppKit

/// Building a bar's items from a space's windows: the tiled
/// windows in order, with adjacent same-app runs optionally
/// collapsed into groups. Shared by the per-display driver
/// (`KiwiCore+AppBar`) and the drag reorder.
extension KiwiCore {
    /// The window whose App Bar item renders *focused* for
    /// `space`. On the **active** space this is the shared
    /// `focusAnchor` — the system frontmost when a tiled-sticky
    /// traveler holds it, else the space's own slot: a traveler
    /// holds the focus but can never be the membership-guarded
    /// slot (#431), so `space.focused` would leave its item on the
    /// unfocused tier and never expand its group (the fix the
    /// Space Bar already carries, #414). Delegating to
    /// `focusAnchor` (rather than raw `lastFocused`) also inherits
    /// its `tiled`-membership guard: right after a bare switch a
    /// stale global `lastFocused` that is a *non-traveler* on the
    /// previous space falls back to this space's own focus instead
    /// of transiently blanking the highlight (a stale *traveler*
    /// is injected here, so it deliberately surfaces, matching
    /// Scrolling and Monocle). Every **inactive**-
    /// display space keeps its remembered `focused`, which never
    /// holds the system focus. (The Space Bar reads raw
    /// `lastFocused`: its items are spaces, so a non-active
    /// space's group never contains it — no guard needed there.)
    func appBarFocused(of space: Space) -> WindowID? {
        guard space.id == activeSpace?.id else {
            return space.focused
        }
        return state.focusAnchor(
            of: space,
            tiled: state.effectiveTiledMembers(
                of: space,
                activeSpace: activeSpace?.id
            )
        )
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

    /// The text one item draws, resolved here so `AppBarOverlay`
    /// stays a dumb renderer — the same seam the glyph already
    /// takes.
    ///
    /// The app name is the fallback in the two places a title
    /// cannot speak, and only there:
    ///
    /// - A **collapsed group** holds several windows with several
    ///   titles, and no one of them is true of the group. (Its
    ///   members are reachable as titles the moment focus enters
    ///   it — `barGroups` expands the focused group — so nothing
    ///   is lost, only deferred.)
    /// - An **empty title**. Lazy-title apps (Electron/WebKit,
    ///   #160) are tracked before their titles arrive, and four
    ///   of twelve apps on a real desktop reported none at all
    ///   (owner 2026-08-19). Without this the bar would draw
    ///   blank slots for them at every launch.
    ///
    /// Only the title is capped: app names are short by
    /// construction (6–20 characters observed), so capping the
    /// fallback would be a clamp that never fires.
    func barItemText(
        for group: [WindowID],
        window: ManagedWindow?,
        appName: String,
        style: AppBarStyle
    ) -> String {
        guard group.count == 1,
            let title = window?.title,
            !title.isEmpty
        else { return appName }
        return AppBarStyle.cappedTitle(
            title,
            to: style.resolvedTitleCap
        )
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
            text: barItemText(
                for: group,
                window: window,
                appName: name,
                style: style
            ),
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
