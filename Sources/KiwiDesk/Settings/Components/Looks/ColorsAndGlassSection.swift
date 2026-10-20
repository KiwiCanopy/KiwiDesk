import KiwiDeskCore
import SwiftUI

/// Looks & Animations ▸ Colors & glass (#2389): the finish first,
/// then every colour by role and by surface — one collapsible
/// card, shut on every visit, its groups split by hairlines so no
/// card sits inside a card. The one area a colour renders in
/// (`SettingsColorSurfaceTests`).
struct ColorsAndGlassSection: View {
    @ObservedObject var model: SettingsModel
    @State private var expanded = false

    var body: some View {
        SettingsCollapsibleSection(
            SettingsCatalog.colors.colorsAndGlass,
            isExpanded: $expanded,
            summary: summary
        ) {
            VStack(alignment: .leading, spacing: 14) {
                GlassCard(model: model)
                Divider()
                RoleColorCards(model: model)
                Divider()
                KiwiShelfColorCard(model: model)
                Divider()
                WindowMarksColorCard(model: model)
            }
            .padding(.top, 4)
        }
    }

    /// The control a landing on the section reveals: its first
    /// group, since a drawer opens only for a child (#1250) — so a
    /// reorder of the groups moves this one line.
    nonisolated static var head: SettingsControl {
        SettingsCatalog.colors.colorsAndGlass.children.liquidGlassGroup
    }

    /// Where the section is, for a sentence on another page that
    /// sends the user to a colour (#818).
    static var place: String {
        L(
            "colors.colors_and_glass.place",
            "%1$@ ▸ %2$@",
            SettingsDestination.looks.title,
            SettingsCatalog.colors.colorsAndGlass.control.text
        )
    }

    /// What the finish is set to; the colours speak for themselves
    /// once open. Below macOS 26 the glass row is absent, so its
    /// value is too.
    private var summary: String {
        let sheen = SettingsValueReadout.sheen(
            model.config.settings.borderStyle.sheen
        )
        guard AppBarStyle.glassAvailable else {
            return L(
                "colors.colors_and_glass.summary.sheen",
                "%1$@: %2$@",
                SheenRow.label,
                sheen
            )
        }
        // The rows' own labels, interpolated (#818).
        return L(
            "colors.colors_and_glass.summary",
            "%1$@: %2$@ · %3$@: %4$@",
            GlassCard.title,
            SettingsValueReadout.onOff(model.liquidGlassMaster.wrappedValue),
            SheenRow.label,
            sheen
        )
    }
}
