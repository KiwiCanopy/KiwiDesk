import KiwiDeskCore
import SwiftUI

/// Layout defaults configuration section (#678 Phase 3 turn 10).
struct LayoutDefaultsSection: View {
    @ObservedObject var model: SettingsModel

    /// Selected layout mode binding stored on navigation model (#277).
    private var selected: Binding<LayoutMode> {
        Binding(
            get: { model.nav.layoutModeTab ?? initialMode },
            set: { model.nav.layoutModeTab = $0 }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                minSizeSection
                LayoutStrip(model: model, selection: selected)
                LayoutCard(
                    model: model,
                    mode: selected.wrappedValue
                )
            }
            .padding(.horizontal, SettingsMetrics.paneInset)
            .settingsPageBottom()
        }
        // Land on the most-used layout, then leave the selection
        // alone — latched by writing the model once, or `selected`
        // would keep re-deriving `initialMode` and adding a space
        // elsewhere could move this page under the user. Cleared
        // by `SettingsNavigation.resetSurfaces()` per visit.
        .onAppear {
            if model.nav.layoutModeTab == nil {
                model.nav.layoutModeTab = initialMode
            }
        }
    }

    /// Profile's most used layout mode (`LayoutUsage.mostUsed`).
    private var initialMode: LayoutMode {
        LayoutUsage.mostUsed(in: model.config)
    }

    /// Global minimum window size setting section.
    private var minSizeSection: some View {
        SettingsSection(
            SettingsCatalog.layoutDefaults.minWindowSize,
            caption: L(
                "layout_defaults.min_size.caption",
                "Windows never tile smaller than this. Set a layout "
                    + "apart under %1$@.",
                MinWindowSizeRows.perLayout
            )
        ) {
            ForEach(LayoutDefaultsRowOrder.general, id: \.id) {
                key in
                generalRow(key)
            }
        }
    }

    @ViewBuilder
    private func generalRow(_ key: SettingKey) -> some View {
        switch key {
        case .behaviour(.minWindowSize):
            MinWindowSizeRows(model: model)
        case .behaviour(let follower)
        where MinSizeText.followers.contains(follower):
            // Drawn by the master's drawer above.
            EmptyView()
        default:
            let _ = assertionFailure(
                "unrendered Layout Defaults general row: \(key.id)"
            )
            EmptyView()
        }
    }
}
