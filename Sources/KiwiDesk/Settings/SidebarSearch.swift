import KiwiDeskCore
import SwiftUI

/// Sidebar search (#90, tier 1): matches the query against the
/// destination titles and the subsection headers each
/// destination renders — localized, so search finds what the
/// user actually sees. Per-control search, scroll-to +
/// highlight, and the Layout Defaults mode auto-select are
/// tier 2 (#277).

/// One search hit: a destination row, plus the matched
/// subsection header when the destination title itself did not
/// match — the caption tells the user where inside the tab to
/// look (for Layout Defaults' mode-gated editors it names the
/// mode tab to open, so a hit hidden behind the mode strip is
/// a foreseeable extra click, not a silent dead end).
struct SidebarSearchResult: Identifiable, Equatable {
    let destination: SettingsDestination
    let subsection: String?
    var id: SettingsDestination { destination }
}

enum SidebarSearch {
    /// Case- and diacritic-insensitive substring match
    /// (`localizedStandardContains`, Apple's user-facing
    /// search comparison — "grosse" finds "Größe"), one row
    /// per destination in sidebar order;
    /// the first matching subsection wins the caption.
    /// Destinations the sidebar hides while a stored profile
    /// is edited stay out of the results too — the fourth #18
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
        if destination.title
            .localizedStandardContains(query)
        {
            return SidebarSearchResult(
                destination: destination,
                subsection: nil
            )
        }
        let hit = subsections(of: destination).first {
            $0.localizedStandardContains(query)
        }
        return hit.map {
            SidebarSearchResult(
                destination: destination,
                subsection: $0
            )
        }
    }

    /// The subsection headers each destination renders, in
    /// render order, as the exact `L(key, english)` tuples of
    /// their view call sites — `extract-keys --check` fails
    /// the gate if a tuple drifts from its twin, and
    /// `SidebarSearchParityTests` pins that every key here
    /// still has a rendering call site. Computed titles (the
    /// per-layout "%1$@ bar") and per-control labels stay out
    /// until #277.
    /// Known limit (recorded, #293): `.bars` hosts two
    /// editors behind a local switch that always opens on App
    /// Bar, so a hit on a `space_bar.*` header lands one click
    /// away (the caption names the section). Sub-target
    /// navigation is #277's per-control catalog territory.
    @MainActor static func subsections(
        of destination: SettingsDestination
    ) -> [String] {
        switch destination {
        case .spaces:
            return [L("spaces.title", "Spaces")]
        case .layoutDefaults:
            return [
                L(
                    "layout_defaults.min_window_size",
                    "Minimum window size"
                )
            ] + LayoutMode.placementTabs.map(\.displayName)
        case .monitors:
            return [
                L(
                    "monitors.space_placement",
                    "Space placement"
                ),
                L(
                    "monitors.orphan_pins.title",
                    "Pinned to disconnected monitors"
                ),
                L(
                    "monitors.advanced.title",
                    "Advanced — monitor fingerprints"
                ),
            ]
        case .appearance:
            return [
                L("palettes.title", "Color Palette"),
                L("gaps.title", "Gaps"),
                L("gaps.per_edge", "Per-edge…"),
                L("gaps.per_axis", "Per-axis…"),
                L("drag.title", "Drag & Drop"),
                L("drag.ghost", "Ghost"),
                L("drag.drop_zone", "Drop zone"),
                L("border.title", "Focus border"),
                L("sticky.title", "Sticky windows"),
            ]
        case .bars:
            return [
                L(
                    "app_bar.global_style.title",
                    "Global style"
                ),
                L(
                    "app_bar.global_colors.title",
                    "Global colors"
                ),
                // Renders inside both colour groups; placed at
                // its first render position, since the contract
                // is render order and the first match wins the
                // caption.
                L("bars.advanced_colors", "Advanced colors"),
                L(
                    "space_bar.global_style.title",
                    "Space Bar style"
                ),
                L(
                    "space_bar.colors.title",
                    "Space Bar colors"
                ),
            ]
        case .behavior:
            return [
                L("behavior.mouse.title", "Mouse"),
                L(
                    "behavior.animations.title",
                    "Animations"
                ),
                L("behavior.quit.title", "On Quit"),
            ]
        case .profiles:
            return [
                L(
                    "profiles.saved.title",
                    "Saved profiles"
                ),
                L("presets.title", "Presets"),
                L(
                    "native_spaces.title",
                    "Profiles per macOS Space"
                ),
            ]
        case .shortcuts:
            return [
                L(
                    "shortcuts.section.switch_modes",
                    "Switch modes"
                ),
                L("shortcuts.section.focus", "Focus"),
                L(
                    "shortcuts.section.move_windows",
                    "Move Windows"
                ),
                L(
                    "shortcuts.section.size_float",
                    "Size & Float"
                ),
                L(
                    "shortcuts.section.open_applications",
                    "Open Applications"
                ),
                L("shortcuts.section.general", "General"),
                L(
                    "shortcuts.section.inactive",
                    "Inactive shortcuts"
                ),
                L(
                    "shortcuts.override.title",
                    "Profile shortcuts"
                ),
                L(
                    "shortcuts.advanced.title",
                    "Advanced: Lua bindings"
                ),
            ]
        case .appRules:
            return [
                L(
                    "app_rules.section.title",
                    "Rules per app"
                )
            ]
        case .general:
            return [
                L(
                    "general.language.title",
                    "Language"
                ),
                L("general.about.title", "About"),
                L("general.advanced.title", "Advanced"),
            ]
        }
    }
}
