import KiwiDeskCore
import SwiftUI

/// Simple's one page (#2737, #2777): KiwiHub, Look, a card per
/// Space and Open applications, ended by the support strip and
/// Home's footer, in one centred column at every width. Simple owns
/// layout only — every control it draws is Advanced's own.
struct SimpleScreen: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.settingsWidth) private var width

    /// The one top gutter, Home's (#1536).
    private static let topGutter: CGFloat = 24
    /// The column's widest, and the room it keeps from the window's
    /// edges below that (#2777 ruling 1).
    static let columnCap: CGFloat = 1120
    static let sideRoom: CGFloat = 40

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
                .frame(
                    width: min(
                        Self.columnCap,
                        geo.size.width - 2 * Self.sideRoom
                    )
                )
                // The strip's footer reaches the window's bottom
                // inset, as on Home.
                .frame(
                    minHeight: geo.size.height - Self.topGutter
                        - SettingsMetrics.pageBottom(width),
                    alignment: .top
                )
                .padding(.bottom, SettingsMetrics.pageBottom(width))
                .padding(.top, Self.topGutter)
                .frame(maxWidth: .infinity)
            }
        }
        // A row or tile removed under the pointer sends no leave, so
        // a hover must not outlive the page (gui.md ▸ SwiftUI traps).
        .onDisappear { model.nav.simpleHover = nil }
    }
}
