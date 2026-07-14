import KiwiDeskCore
import SwiftUI

/// This Profile ▸ App Bar (#229): the App Bar earned its own
/// sidebar destination, out of Appearance's one long scroll. It
/// hosts the global look every layout inherits plus the two
/// per-layout override sections (monocle, scrolling) — the same
/// content that used to close Appearance, now a first-class,
/// deep-linkable place. Being its own page, it needs no group
/// title (the sidebar label already names it).
struct AppBarSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GlobalAppBarSection(
                    style: $model.config.settings.appBarStyle
                )
                LayoutAppBarSection(
                    title: L("layout.monocle.name", "Monocle"),
                    mode: .monocle,
                    bar: $model.config.settings.monocle.appBar,
                    global: model.config.settings.appBarStyle
                )
                LayoutAppBarSection(
                    title: L(
                        "layout.scrolling.name",
                        "Scrolling"
                    ),
                    mode: .scrolling,
                    bar: $model.config.settings.scrolling.appBar,
                    global: model.config.settings.appBarStyle
                )
            }
            .padding(16)
        }
    }
}
