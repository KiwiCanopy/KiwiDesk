import KiwiDeskCore
import SwiftUI

/// Simple's one page (#2737): Look, Spaces, KiwiHub and Open
/// applications, ended by the support strip and Home's footer at
/// every width. Simple owns layout only — every control it draws
/// is Advanced's own.
struct SimpleScreen: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.settingsWidth) private var width

    /// The one top gutter, Home's (#1536).
    private static let topGutter: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // First: it teaches the keys the tour taught,
                    // before any control (ui-designer, #2737).
                    SimpleKiwiHubKeys(model: model)
                    SimpleLookCard(model: model)
                    SimpleSpacesCard(model: model)
                    SimpleShortcutCards(model: model)
                    HomeSupportStrip(model: model)
                }
                // The strip's footer reaches the window's bottom
                // inset, as on Home.
                .frame(
                    minHeight: geo.size.height - Self.topGutter
                        - SettingsMetrics.pageBottom(width),
                    alignment: .top
                )
                .padding(.horizontal, SettingsMetrics.paneInset)
                .padding(.bottom, SettingsMetrics.pageBottom(width))
                .padding(.top, Self.topGutter)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
