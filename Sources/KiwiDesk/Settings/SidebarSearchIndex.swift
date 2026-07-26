import KiwiDeskCore
import SwiftUI

/// The searchable things inside each destination, in render
/// order, as the exact `L(key, english)` tuples of their view
/// call sites — `extract-keys --check` fails the gate if a tuple
/// drifts from its twin, and `SidebarSearchParityTests` pins that
/// every key here still has a rendering call site *and* that no
/// rendered header escapes the index.
///
/// Split out of `SidebarSearch` when tier 2 (#277) gave entries a
/// surface: the matching logic is small and stable, the list is
/// neither, and the per-control catalog will grow it much
/// further.

/// One indexed thing: the localized text the user sees, and the
/// local surface that must be selected for it to be on screen at
/// all.
///
/// The text doubles as the scroll anchor id — see
/// `SettingsAnchor` for why identity is the label text rather
/// than the `L()` key.
struct SidebarSearchEntry: Equatable {
    let text: String
    var surface: SettingsSurface = .main
}

extension SidebarSearch {
    /// Per-control labels are tier 2 part 2; today this is
    /// section headers, drawer labels and the mode tabs.
    ///
    /// Known limit (recorded, #277): the per-Space "Overrides…"
    /// popover is not indexed. It is reached from a row button
    /// rather than a destination, so there is nothing for a
    /// reveal to select — a stronger bar than the `.bars` switch,
    /// which IS indexed because a switch is part of the pane. Its
    /// rows also duplicate `layout_params.*` labels that the
    /// Layout Defaults tabs already carry, so the user's word is
    /// findable either way.
    @MainActor static func entries(
        of destination: SettingsDestination
    ) -> [SidebarSearchEntry] {
        switch destination {
        case .spaces:
            return [.init(text: L("spaces.title", "Spaces"))]
        case .layoutDefaults:
            return layoutDefaultsEntries
        case .monitors:
            return [
                .init(
                    text: L(
                        "monitors.space_placement",
                        "Space placement"
                    )
                ),
                .init(
                    text: L(
                        "monitors.orphan_pins.title",
                        "Pinned to disconnected monitors"
                    )
                ),
                .init(
                    text: L(
                        "monitors.advanced.title",
                        "Monitor fingerprints"
                    )
                ),
            ]
        case .appearance:
            return appearanceEntries
        case .bars:
            return barsEntries
        case .behavior:
            return [
                .init(
                    text: L("behavior.mouse.title", "Mouse")
                ),
                .init(
                    text: L(
                        "behavior.animations.title",
                        "Animations"
                    )
                ),
                .init(
                    text: L("behavior.quit.title", "On quit")
                ),
            ]
        case .profiles:
            return [
                .init(
                    text: L(
                        "profiles.saved.title",
                        "Saved profiles"
                    )
                ),
                .init(text: L("presets.title", "Presets")),
                .init(
                    text: L(
                        "native_spaces.title",
                        "Profiles per macOS Space"
                    )
                ),
            ]
        case .shortcuts:
            return shortcutsEntries
        case .appRules:
            return [
                .init(
                    text: L(
                        "app_rules.section.title",
                        "Rules per app"
                    )
                )
            ]
        case .general:
            return [
                .init(
                    text: L("general.language.title", "Language")
                ),
                .init(
                    text: L("general.about.title", "About")
                ),
                .init(
                    text: L("general.advanced.title", "Advanced")
                ),
            ]
        }
    }

    /// The min-size card sits above the strip and feeds every
    /// mode, so it is surface-free; each tab names its own mode,
    /// so a hit selects that tab (#277 sub-problem 2 — the fix
    /// tier 1 could only mitigate with a caption).
    @MainActor private static var layoutDefaultsEntries: [SidebarSearchEntry] {
        [
            .init(
                text: L(
                    "layout_defaults.min_window_size",
                    "Minimum window size"
                )
            )
        ]
            + LayoutMode.placementTabs.map {
                .init(
                    text: $0.displayName,
                    surface: .layoutMode($0)
                )
            }
    }

    @MainActor private static var appearanceEntries: [SidebarSearchEntry] {
        [
            .init(text: L("palettes.title", "Color palette")),
            .init(text: L("gaps.title", "Gaps")),
            .init(text: L("gaps.per_edge", "Per-edge…")),
            .init(text: L("gaps.per_axis", "Per-axis…")),
            .init(text: L("drag.title", "Drag & drop")),
            .init(text: L("drag.ghost", "Ghost")),
            .init(text: L("drag.drop_zone", "Drop zone")),
            .init(text: L("border.title", "Focus border")),
            .init(text: L("sticky.title", "Sticky windows")),
        ]
    }

    /// Both bar editors live behind one switch, so every entry
    /// here names the side it is on — tier 1 could only put that
    /// in a caption and leave the click to the user.
    @MainActor private static var barsEntries: [SidebarSearchEntry] {
        [
            .init(
                text: L(
                    "app_bar.global_style.title",
                    "Global style"
                ),
                surface: .bar(.appBar)
            ),
            .init(
                text: L(
                    "app_bar.global_colors.title",
                    "Global colors"
                ),
                surface: .bar(.appBar)
            ),
            // Renders inside BOTH colour groups, so it stays
            // surface-free on purpose: pinning it to one side
            // would yank a user reading the other bar across the
            // switch to an identically-named drawer, which is
            // worse than tier 1's plain "open the tab". Both
            // drawers carry the anchor, and only one editor
            // renders at a time, so the reveal lands on whichever
            // side is already showing.
            .init(
                text: L(
                    "bars.advanced_colors",
                    "Advanced colors"
                )
            ),
            .init(
                text: L(
                    "space_bar.global_style.title",
                    "Space Bar style"
                ),
                surface: .bar(.spaceBar)
            ),
            .init(
                text: L(
                    "space_bar.colors.title",
                    "Space Bar colors"
                ),
                surface: .bar(.spaceBar)
            ),
        ]
    }

    @MainActor private static var shortcutsEntries: [SidebarSearchEntry] {
        [
            .init(
                text: L(
                    "shortcuts.section.switch_modes",
                    "Switch modes"
                )
            ),
            .init(
                text: L("shortcuts.section.focus", "Focus")
            ),
            .init(
                text: L(
                    "shortcuts.section.move_windows",
                    "Move windows"
                )
            ),
            .init(
                text: L(
                    "shortcuts.section.size_float",
                    "Size & float"
                )
            ),
            .init(
                text: L(
                    "shortcuts.section.open_applications",
                    "Open applications"
                )
            ),
            .init(
                text: L("shortcuts.section.general", "General")
            ),
            .init(
                text: L(
                    "shortcuts.section.inactive",
                    "Inactive shortcuts"
                )
            ),
            .init(
                text: L(
                    "shortcuts.override.title",
                    "Profile shortcuts"
                )
            ),
            .init(
                text: L(
                    "shortcuts.advanced.title",
                    "Lua bindings"
                )
            ),
        ]
    }
}
