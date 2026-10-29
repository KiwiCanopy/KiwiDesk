import KiwiDeskCore
import SwiftUI

/// Simple's one page (#2737, #2777): KiwiHub, Look, a card per
/// Space and Open applications, ended by the support strip and
/// Home's footer, in one centred column at every width. Simple owns
/// layout only — every control it draws is Advanced's own.
struct SimpleScreen: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.settingsWidth) private var width
    /// Whether the sections are in place: false only while the
    /// switch's converge has yet to play (#2777).
    @State private var arrived: Bool

    init(model: SettingsModel) {
        self.model = model
        _arrived = State(initialValue: !model.nav.convergePending)
    }

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
                        .modifier(converge(0, geo.size))
                    SimpleLookCard(model: model)
                        .modifier(converge(1, geo.size))
                    SimpleSpacesCard(model: model)
                        .modifier(converge(2, geo.size))
                    SimpleShortcutCards(model: model)
                        .modifier(converge(3, geo.size))
                    HomeSupportStrip(model: model)
                        .modifier(converge(4, geo.size))
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
        .coordinateSpace(name: HomeConverge.space)
        .onAppear {
            arrived = true
            model.nav.convergePending = false
        }
        // A row or tile removed under the pointer sends no leave, so
        // a hover must not outlive the page (gui.md ▸ SwiftUI traps).
        .onDisappear { model.nav.simpleHover = nil }
    }

    /// Section `index`'s flight from the window's centre.
    private func converge(_ index: Int, _ viewport: CGSize) -> HomeConverge {
        HomeConverge(arrived: arrived, index: index, viewport: viewport)
    }
}
