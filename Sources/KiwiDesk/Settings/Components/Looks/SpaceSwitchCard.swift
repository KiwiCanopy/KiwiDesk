import KiwiDeskCore
import SwiftUI

/// The Space switch card (#3218): how a switch shows itself and
/// the scroll step's twin. App-wide (#1741), so
/// it is a card of its own under `LiveSettingNote`, after the
/// profile's Animations card, and outside Reduce Motion's grey:
/// the slide falls back to Show the Space there (#2524).
struct SpaceSwitchCard: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        SettingsSection(
            SettingsCatalog.colors.spaceSwitchCard,
            liveNote: spaceTransitionLuaOwned ? nil : LiveSettingNote.text
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(ColorsRowOrder.spaceSwitch, id: \.id) { key in
                    row(for: key)
                }
            }
        }
    }

    @ViewBuilder private func row(for key: SettingKey) -> some View {
        switch key {
        case .colours(.spaceTransition): spaceTransitionRow
        case .colours(.spaceScrollTransition): spaceScrollTransitionRow
        default:
            let _ = assertionFailure(
                "unrendered Space switch census key: \(key.id)"
            )
            EmptyView()
        }
    }
}
