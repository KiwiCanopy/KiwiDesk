import KiwiDeskCore
import SwiftUI

/// "Spaces using <layout>" (turn 10): which of the reader's
/// spaces the card above them actually governs, and how many of
/// those deviate from it.
///
/// The card exists because Layout Defaults edits *defaults*, and
/// a default with nothing running it is an hour spent on
/// nothing. It is also where the per-space overrides get named:
/// the numbers here are the one place the page admits that what
/// it sets is not necessarily what a given space does.
struct SpacesUsingLayout: View {
    @ObservedObject var model: SettingsModel
    let mode: LayoutMode

    var body: some View {
        SettingsSection(
            SettingsCatalog.layoutDefaults.spacesUsing
        ) {
            if spaces.isEmpty {
                Text(
                    L(
                        "layout_defaults.spaces_using.none",
                        "No space uses this layout yet — set one "
                            + "to it in Spaces & Layouts."
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                WrapChips(spaces) { space in
                    SpaceChip(label: space.raw)
                }
            }
            if overriding > 0 {
                CrossReferenceRow(
                    prose: overrideProse,
                    linkTitle: L(
                        "layout_defaults.spaces_using.link",
                        "Spaces & Layouts"
                    ),
                    destination: .spaces
                )
            }
        }
    }

    /// Spaces on this layout, in the user's own space order — a
    /// space with no recorded mode runs the default (`?? .bsp`),
    /// the same reading every other surface uses.
    private var spaces: [SpaceID] {
        model.config.spaces.filter {
            (model.config.spaceModes[$0] ?? .bsp) == mode
        }
    }

    /// How many of those spaces override at least one of this
    /// layout's parameters, so the rows above are not the whole
    /// story for them.
    private var overriding: Int {
        spaces.filter { overrides(mode).contains($0) }.count
    }

    /// The spaces carrying a per-space override for `mode`. One
    /// switch over the layouts, so a layout gaining an override
    /// map has exactly one place to be added.
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

    private var overrideProse: String {
        overriding == 1
            ? L(
                "layout_defaults.spaces_using.overridden_one",
                "1 of them overrides these values — edit it in"
            )
            : L(
                "layout_defaults.spaces_using.overridden_many",
                "%1$d of them override these values — edit them "
                    + "in",
                overriding
            )
    }
}
