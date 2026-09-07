import KiwiDeskCore
import SwiftUI

/// The one Liquid Glass switch, over both bars and the ⌃⌥K
/// shortcuts panel (#1307).
struct GlassCard: View {
    @ObservedObject var model: SettingsModel

    private var agreement: LiquidGlassAgreement {
        LiquidGlassAgreement(settings: model.config.settings)
    }

    var body: some View {
        // Hidden below macOS 26, never greyed: an OS-capability
        // gate is an absence (#390), and the census records it
        // in the HIDES group.
        if AppBarStyle.glassAvailable {
            SettingsSection(
                SettingsCatalog.colors.glassCard,
                caption: caption
            ) {
                ForEach(
                    ColorsRowOrder.glassAtRest,
                    id: \.id
                ) { _ in
                    ToggleRow(
                        label: Self.title,
                        isOn: model.liquidGlassMaster,
                        help: agreement.differ
                            ? differHelp : baseHelp
                    )
                }
            }
        }
    }

    /// ONE key for the card and its only row: the product name
    /// twice under its own header is a second string nothing
    /// holds in step (localization-auditor, 2026-09-07).
    static var title: String {
        L("colors.liquid_glass", "Liquid Glass")
    }

    private var caption: String {
        L(
            "colors.glass.caption",
            "A translucent material over both bars and the "
                + "shortcuts panel."
        )
    }

    /// The material's NAME is deliberately absent from both help
    /// strings: it survives verbatim in every catalog, and a
    /// Latin name inside a translated sentence trips the
    /// residue guard in the non-Latin ones. The card's title
    /// carries it directly above.
    private var baseHelp: String {
        L(
            "colors.liquid_glass.help",
            "Lays macOS's translucent material over the Space "
                + "Bar, the App Bar and the shortcuts panel. "
                + "Each bar's %1$@ color tints its own "
                + "material; the shortcuts panel stays "
                + "untinted.",
            L("app_bar.color.fill", "Fill")
        )
    }

    /// Owed only while the three disagree, which only Lua or an
    /// imported profile can produce: a boolean cannot show "two
    /// of three", so this sentence carries what the switch
    /// cannot, and both read the ONE `LiquidGlassAgreement`.
    private var differHelp: String {
        L(
            "colors.liquid_glass.differ.help",
            "The two bars and the panel are set differently "
                + "right now. Turning this on switches it on for "
                + "all three."
        )
    }
}
