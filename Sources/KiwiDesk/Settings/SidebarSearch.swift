import KiwiDeskCore
import SwiftUI

/// Sidebar search: matches the query against the destination
/// titles and everything `SettingsCatalog` declares inside them —
/// localized, so search finds what the user actually sees.
///
/// Tier 1 (#90) stopped at naming the destination and left the
/// user to hunt. Tier 2 (#277) makes a hit *land*: the result
/// carries a `SettingsAnchor`, so picking it selects the
/// destination, switches the local surface that renders the match
/// (a Layout Defaults mode tab, the Bars switch), expands the
/// drawer holding it if collapsed, scrolls the pane to it and
/// flashes it.

/// One search hit, at most one per destination.
///
/// `primary` is the deepest string that actually matched, and
/// that flip is deliberate (ui-designer 2026-07-27): the user
/// typed a word looking for that specific thing, so the row's
/// biggest text is the word they typed — the destination they
/// could already infer becomes the breadcrumb above it. A
/// destination-title match keeps the tier-1 shape exactly
/// (primary = the destination, no path).
struct SidebarSearchResult: Identifiable, Equatable {
    let destination: SettingsDestination
    /// Where to land. Its `anchor` is nil when the destination
    /// title itself matched — there is no finer target than the
    /// tab, so the pane opens without scrolling.
    let anchor: SettingsAnchor
    /// The matched text; the result row's primary line.
    let primary: String
    /// The ancestors above `primary`, outermost first.
    let path: [String]
    var id: SettingsDestination { destination }
}

enum SidebarSearch {
    /// Substring match through `searchMatches` — the app's one
    /// search-matching predicate, shared with the app picker:
    /// case- and diacritic-insensitive ("grosse" finds "Größe")
    /// and separator-insensitive ("space bar farben" finds
    /// "Space Bar-Farben"). One row per destination, in sidebar
    /// order.
    ///
    /// One row per destination is the settled cap (ui-designer
    /// 2026-07-27): a query like "color" hits many controls, and
    /// enumerating each would build a forty-row wall in the
    /// sidebar's narrow fixed column (`sidebarColumn`) for
    /// information the click cannot act on anyway. The
    /// honest trade-off is that a destination with several
    /// matches surfaces only its first, and a user who wanted
    /// another narrows the query — the same escape hatch System
    /// Settings relies on.
    ///
    /// Destinations the sidebar hides while a stored profile is
    /// edited stay out of the results too — the fourth #18
    /// enforcement point, through the same
    /// `isReachable(editingStoredProfile:)` predicate, never a
    /// hand-negated copy.
    @MainActor static func results(
        query: String,
        editingStoredProfile: Bool
    ) -> [SidebarSearchResult] {
        let query = query.trimmed
        guard !query.isEmpty else { return [] }
        let ordered =
            SettingsDestination.thisProfile
            + SettingsDestination.wholeApp
        return ordered.compactMap { destination in
            guard
                destination.isReachable(
                    editingStoredProfile: editingStoredProfile
                )
            else { return nil }
            return match(query, in: destination)
        }
    }

    @MainActor private static func match(
        _ query: String,
        in destination: SettingsDestination
    ) -> SidebarSearchResult? {
        let title = destination.title
        if title.searchMatches(query) {
            return SidebarSearchResult(
                destination: destination,
                anchor: SettingsAnchor(destination: destination),
                primary: title,
                path: []
            )
        }
        guard
            let hit = SettingsCatalog.entries(of: destination)
                .first(where: {
                    $0.control.text.searchMatches(query)
                })
        else { return nil }
        return SidebarSearchResult(
            destination: destination,
            anchor: SettingsAnchor(
                destination: destination,
                surface: hit.control.surface,
                anchor: hit.control.id
            ),
            primary: hit.control.text,
            path: path(to: hit, in: destination)
        )
    }

    /// The breadcrumb above a hit: the destination, then the
    /// surface that renders it, then the drawer it sits inside.
    ///
    /// The surface is always named when there is one — including
    /// the Bars switch's default side. Naming "Space Bar" tells
    /// the user *which of the two bars* they found, which is the
    /// information they came for; suppressing it because that
    /// side happens to open first would leak a default into copy.
    /// A mode tab whose own name IS the match ("Stack") is not
    /// repeated above itself. A drawer-interior hit names its
    /// drawer ("Appearance › Per-edge…"), since a bare "Top"
    /// says nothing about which control was found.
    @MainActor private static func path(
        to entry: SettingsIndexEntry,
        in destination: SettingsDestination
    ) -> [String] {
        var path = [destination.title]
        if let surface = entry.control.surface.displayName,
            surface != entry.control.text
        {
            path.append(surface)
        }
        if let parent = entry.parent {
            path.append(parent.text)
        }
        return path
    }
}

extension SettingsSurface {
    /// The surface's own user-facing name, reusing the exact
    /// tuples of the controls that select it, or nil for `.main`.
    @MainActor var displayName: String? {
        switch self {
        case .main: return nil
        case .layoutMode(let mode): return mode.displayName
        }
    }
}
