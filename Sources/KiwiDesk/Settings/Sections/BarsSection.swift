import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Bars, the first area rendered from the
/// settings census (#678 Phase 2, turn 7a): one page — the
/// Space Bar card, the App Bar card with its "Show it in"
/// switches, then the interim colour cards. The #293 App Bar /
/// Space Bar switch is gone: both cards fit one scroll now that
/// the per-layout override sub-editors left the GUI
/// (GUI_REMOVED_2026-08; per-layout styling stays fully
/// available in Lua).
///
/// Space Bar leads, matching everywhere else it does
/// (ui-designer 2026-07-19): it is omnipresent across every
/// layout, while the App Bar renders only where a layout shows
/// one.
///
/// The colour cards are interim: the census places bar colours
/// in Advanced Colours, which the Colours phase renders; until
/// then they keep the only colour GUI alive, below the
/// structural cards they used to share an editor with.
struct BarsSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SpaceBarCard(model: model)
                AppBarCard(model: model)
                spaceBarColors
                appBarColors
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
    }

    private var gates: BarsGateContext {
        BarsGateContext(settings: model.config.settings)
    }

    /// The colour cards keep the #527 shape: the header `?` is
    /// the block gate's live anchor, and the gate is passed IN,
    /// not wrapped around, so each "Advanced colors" disclosure
    /// label stays clickable while its swatches dim.
    private var spaceBarColors: some View {
        let on = model.config.settings.spaceBarStyle.enabled
        return SettingsSection(
            SettingsCatalog.bars.spaceBarColorsCard,
            help: on ? nil : BarsGateHelp.spaceBarOff
        ) {
            SpaceBarColorsGroup(
                model: model,
                gatedOff: !on,
                gateHelp: BarsGateHelp.spaceBarOff
            )
        }
    }

    private var appBarColors: some View {
        let shown = gates.anyBarShown
        return SettingsSection(
            SettingsCatalog.bars.appBarColorsCard,
            help: shown ? nil : BarsGateHelp.noBarShown
        ) {
            AppBarColorsGroup(
                style: $model.config.settings.appBarStyle,
                gatedOff: !shown,
                gateHelp: BarsGateHelp.noBarShown,
                gapOnly: gates.gapOnly
            )
        }
    }
}
