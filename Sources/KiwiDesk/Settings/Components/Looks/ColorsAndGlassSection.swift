import KiwiDeskCore
import SwiftUI

/// Looks & Animations ▸ Colors & glass (#2389, #2593): the
/// finish always open, then every other colour by role and by
/// surface in one drawer, shut on every visit, its groups split
/// by hairlines so no card sits inside a card. The one area a
/// colour renders in (`SettingsColorSurfaceTests`).
struct ColorsAndGlassSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        SettingsSection(SettingsCatalog.colors.colorsAndGlass) {
            VStack(alignment: .leading, spacing: 14) {
                GlassCard(model: model)
                SettingsDisclosure(
                    SettingsCatalog.colors.colorsDrawer,
                    summary: summary
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        RoleColorCards(model: model)
                        Divider()
                        KiwiShelfColorCard(model: model)
                        Divider()
                        WindowMarksColorCard(model: model)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    /// The control a landing on the section reveals: its first
    /// group, so a reorder of the groups moves this one line.
    nonisolated static var head: SettingsControl {
        SettingsCatalog.colors.liquidGlassGroup
    }

    /// Where the section is, for a sentence on another page that
    /// sends the user to a colour (#818).
    static var place: String {
        L(
            "colors.colors_and_glass.place",
            "%1$@ ▸ %2$@",
            SettingsDestination.looks.title,
            SettingsCatalog.colors.colorsAndGlass.text
        )
    }

    /// The drawer's groups by their titles (#818), KiwiShelf's
    /// shortened to the product name (#2593).
    private var summary: String {
        let groups = SettingsCatalog.colors.colorsDrawer.children
        return L(
            "colors.colors_drawer.summary",
            "%1$@ · %2$@ · %3$@ · %4$@",
            groups.accentGroup.text,
            groups.secondAccentGroup.text,
            L("bars.switch.kiwishelf", "KiwiShelf"),
            groups.windowMarksGroup.text
        )
    }
}
