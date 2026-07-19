import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Bars (#293): one destination hosting both bar
/// editors behind a fixed `App Bar | Space Bar` switch — each
/// editor leads with its own preview and owns its settings;
/// never both stacked. Renamed from the #229 App Bar page; the
/// App Bar editor keeps every control and per-layout override,
/// the switch only re-homes it.
struct BarsSection: View {
    /// The two editors behind the switch.
    enum Editor: String, CaseIterable {
        case appBar
        case spaceBar
    }

    @ObservedObject var model: SettingsModel
    @State private var editor: Editor = .appBar

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Recognition chips, not a text segment (QA
                // 2026-07-19): the switch itself must show
                // that two different bars exist.
                VStack(alignment: .leading, spacing: 6) {
                    BarEditorPicker(selection: $editor)
                    Text(
                        L(
                            "bars.switch.caption",
                            "KiwiDesk draws two bars — choose "
                                + "which one to configure."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                switch editor {
                case .appBar: appBarEditor
                case .spaceBar:
                    SpaceBarEditorSection(model: model)
                }
            }
            .padding(16)
        }
    }

    /// The pre-#293 App Bar page, unchanged: the global look
    /// every layout inherits plus the two per-layout override
    /// sections.
    @ViewBuilder private var appBarEditor: some View {
        GlobalAppBarSection(
            style: $model.config.settings.appBarStyle,
            spaceBarSharedEdge: model.config.settings
                .spaceBarSharesEdgeWithAppBar
                ? model.config.settings.spaceBarStyle.edge
                : nil
        )
        LayoutAppBarSection(
            title: L("layout.monocle.name", "Monocle"),
            mode: .monocle,
            bar: $model.config.settings.monocle.appBar,
            global: model.config.settings.appBarStyle
        )
        LayoutAppBarSection(
            title: L("layout.scrolling.name", "Scrolling"),
            mode: .scrolling,
            bar: $model.config.settings.scrolling.appBar,
            global: model.config.settings.appBarStyle
        )
    }
}
