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
        SettingsSection(
            SettingsCatalog.colors.glassCard,
            caption: caption
        ) {
            ToggleRow(
                label: L("colors.liquid_glass", "Liquid Glass"),
                isOn: model.liquidGlassMaster,
                help: agreement.differ ? differHelp : baseHelp
            )
        }
    }

    private var caption: String {
        L(
            "colors.glass.caption",
            "A translucent material over both bars and the "
                + "shortcuts panel."
        )
    }

    /// Owed only while the three disagree, which only Lua or an
    /// imported profile can produce: a boolean cannot show
    /// "two of three", so the sentence carries what the switch
    /// cannot, and both read the ONE `LiquidGlassAgreement`.
    private var baseHelp: String {
        L(
            "colors.liquid_glass.help",
            "Lays macOS 26's Liquid Glass material over the "
                + "Space Bar, the App Bar and the shortcuts "
                + "panel. Each bar's Fill color tints its own "
                + "glass; the shortcuts panel stays untinted."
        )
    }

    private var differHelp: String {
        L(
            "colors.liquid_glass.differ.help",
            "The three surfaces are set differently right now. "
                + "Turning this on gives all three Liquid Glass."
        )
    }
}
