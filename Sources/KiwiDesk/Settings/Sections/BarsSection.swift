import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Bars (#293): one destination hosting both bar
/// editors behind a fixed `App Bar | Space Bar` switch — each
/// editor leads with its own preview and owns its settings;
/// never both stacked. Renamed from the #229 App Bar page; the
/// App Bar editor keeps every control and per-layout override,
/// the switch only re-homes it.
struct BarsSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Recognition chips, not a text segment (QA
                // 2026-07-19): the switch itself must show
                // that two different bars exist.
                VStack(alignment: .leading, spacing: 6) {
                    // Space Bar leads and is the default
                    // (ui-designer 2026-07-19): it is omnipresent
                    // across every layout, while the App Bar
                    // renders only in Monocle/Scrolling — landing
                    // in the always-relevant editor first. The
                    // selection lives on the model (#277) so a
                    // search hit on a `space_bar.*` header can
                    // open the editor that renders it.
                    BarEditorPicker(selection: $model.nav.barEditor)
                    Text(switchCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                switch model.nav.barEditor {
                case .appBar: appBarEditor
                case .spaceBar:
                    SpaceBarEditorGroup(model: model)
                }
            }
            .padding(16)
        }
    }

    /// Hoisted out of `body` (§5 shallow-body guardrail:
    /// concatenated literals inside one body expression).
    private var switchCaption: String {
        L(
            "bars.switch.caption",
            "KiwiDesk draws two bars — choose "
                + "which one to configure."
        )
    }

    /// The pre-#293 App Bar page, unchanged: the global look
    /// every layout inherits plus the two per-layout override
    /// sections.
    @ViewBuilder private var appBarEditor: some View {
        GlobalAppBarGroup(
            style: $model.config.settings.appBarStyle,
            spaceBarSharedEdge: model.config.settings
                .spaceBarSharesEdgeWithAppBar
                ? model.config.settings.spaceBarStyle.edge
                : nil,
            layoutBars: model.config.settings.appBarHosts
        )
        LayoutAppBarGroup(
            title: L("layout.monocle.name", "Monocle"),
            mode: .monocle,
            overridesDrawer:
                SettingsCatalog.bars.monocleBarOverrides,
            bar: $model.config.settings.monocle.appBar,
            global: model.config.settings.appBarStyle
        )
        LayoutAppBarGroup(
            title: L("layout.scrolling.name", "Scrolling"),
            mode: .scrolling,
            overridesDrawer:
                SettingsCatalog.bars.scrollingBarOverrides,
            bar: $model.config.settings.scrolling.appBar,
            global: model.config.settings.appBarStyle
        )
    }
}
