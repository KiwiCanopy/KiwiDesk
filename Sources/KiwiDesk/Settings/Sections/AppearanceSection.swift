import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Appearance (#68 §3.2): how KiwiDesk looks
/// while you use it — gaps, the App Bar (global look + the
/// per-layout overrides), and the drag visuals. One topic even
/// though the code splits it across editors.
struct AppearanceSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GapsEditor(model: model)
                GlobalAppBarSection(
                    style: $model.config.settings.appBarStyle
                )
                LayoutAppBarSection(
                    title: "Monocle",
                    mode: .monocle,
                    bar: $model.config.settings.monocle
                        .appBar,
                    global: model.config.settings.appBarStyle
                )
                LayoutAppBarSection(
                    title: "Scrolling",
                    mode: .scrolling,
                    bar: $model.config.settings.scrolling
                        .appBar,
                    global: model.config.settings.appBarStyle
                )
                DragVisualsEditor(model: model)
            }
            .padding(16)
        }
    }
}
