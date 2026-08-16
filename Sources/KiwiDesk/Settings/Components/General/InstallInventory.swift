import KiwiDeskCore
import SwiftUI

/// What this install actually holds — the counts half of #795,
/// re-scoped (owner, 2026-08-16).
///
/// The issue proposed a General detail PANEL listing version,
/// language, login item and config path, plus a line stating what
/// Reset would delete. The panel was ruled against: all four of
/// those facts are already in the content column a few hundred
/// points to the left, so the panel could only restate them, and
/// General's empty right side is a stated verdict rather than a
/// gap (`SettingsDetailPanelOffer` carries that argument).
///
/// The COUNTS were the one thing in the issue that is nowhere on
/// the page, so they ship here instead — in About, which is
/// already the block about this install rather than about any
/// setting in it.
///
/// **Stated about the install, never about Reset.** The issue
/// framed them as "an inventory of exactly what Reset would
/// delete", and that framing is wrong twice. Reset's blast radius
/// is already stated where the user is deciding — under the
/// button and again in its confirm — and `design-decisions.md`
/// rules that a cost landing where the user already is does not
/// get a second warning somewhere they did not ask. It is also
/// unwritable: four counts in one sentence cannot each be last,
/// and `localization.md` requires a count to sit last behind a
/// label so no locale has to agree with a number mid-sentence.
/// Rows of counts satisfy that by construction — which is the
/// localization rule forcing the honest framing on its own.
struct InstallInventory: View {
    @ObservedObject var model: SettingsModel

    /// The four counts, in the order the areas appear in the
    /// sidebar so the block reads as a walk through the app
    /// rather than an arbitrary list.
    ///
    /// Internal so `InstallInventoryTests` reads the numbers: a
    /// row that renders a plausible constant satisfies every
    /// source needle, which is the failure this lane has already
    /// paid for once (`LayoutSchematicCountTests`).
    var rows: [(label: String, count: Int)] {
        [
            (
                L("general.inventory.profiles", "Profiles: %1$d"),
                model.profiles.count
            ),
            (
                L("general.inventory.spaces", "Spaces: %1$d"),
                model.config.spaces.count
            ),
            (
                L(
                    "general.inventory.shortcuts",
                    "Shortcuts: %1$d"
                ),
                shortcutCount
            ),
            (
                L("general.inventory.app_rules", "App rules: %1$d"),
                model.config.appRules.count
            ),
        ]
    }

    /// Every binding across every layer, which is what "how many
    /// shortcuts do I have" means to a reader: a layer is an
    /// alternate SET, and a chord bound only in one still exists.
    /// Counted off the draft's layers rather than the default
    /// layer alone, so an imported or hand-built layer is not
    /// silently invisible here.
    private var shortcutCount: Int {
        model.config.layers.reduce(0) { $0 + $1.bindings.count }
    }

    var body: some View {
        VStack(spacing: 3) {
            ForEach(rows, id: \.label) { row in
                Text(
                    String(
                        format: row.label,
                        locale: .current,
                        row.count
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
        }
        // One element, one sentence: read as four siblings the
        // rotor announces four bare numbers with their labels
        // split across stops, which is the "three elements for
        // one value" shape turn 20a rules against.
        .accessibilityElement(children: .combine)
    }
}
