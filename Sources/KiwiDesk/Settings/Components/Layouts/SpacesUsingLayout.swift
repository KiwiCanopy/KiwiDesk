import KiwiDeskCore
import SwiftUI

/// Read-only display of spaces assigned to selected layout (`LayoutUsage`).
struct SpacesUsingLayout: View {
    @ObservedObject var model: SettingsModel
    let mode: LayoutMode

    var body: some View {
        SettingsSection(
            SettingsCatalog.layoutDefaults.spacesUsing
        ) {
            if spaces.isEmpty {
                Text(emptyProse)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                WrapChips(spaces) { space in
                    SpaceChip(label: space.raw)
                }
            }
            if overriding > 0 {
                CrossReferenceRow(
                    prose: Self.overrideProse(overriding),
                    linkTitle: SettingsDestination.spaces.title,
                    destination: .spaces
                )
            }
        }
    }

    private var spaces: [SpaceID] {
        LayoutUsage.spaces(on: mode, in: model.config)
    }

    /// Number of spaces overriding layout parameters.
    private var overriding: Int {
        spaces.filter { overrides(mode).contains($0) }.count
    }

    /// Set of spaces with custom overrides for layout mode.
    private func overrides(_ mode: LayoutMode) -> Set<SpaceID> {
        let settings = model.config.settings
        switch mode {
        case .bsp: return Set(settings.bsp.override.keys)
        case .stack: return Set(settings.stack.override.keys)
        case .scrolling:
            return Set(settings.scrolling.override.keys)
        case .grid: return Set(settings.grid.override.keys)
        case .monocle:
            return Set(settings.monocle.override.keys)
        case .track: return Set(settings.track.override.keys)
        case .floating: return []
        }
    }

    private var emptyProse: String {
        L(
            "layout_defaults.spaces_using.none",
            "No Space uses this layout yet — set one to it in "
                + "%1$@.",
            SettingsDestination.spaces.title
        )
    }

    /// Formats override cross-reference prose (`CrossReferenceRowSlotTests`).
    static func overrideProse(_ overriding: Int) -> String {
        overriding == 1
            ? L(
                "layout_defaults.spaces_using.overridden_one",
                "1 of them overrides these values — edit it in "
                    + "%1$@.",
                CrossReferenceRow.linkSlot
            )
            : L(
                "layout_defaults.spaces_using.overridden_many",
                "%1$d of them override these values — edit them "
                    + "in %2$@.",
                overriding,
                CrossReferenceRow.linkSlot
            )
    }
}
