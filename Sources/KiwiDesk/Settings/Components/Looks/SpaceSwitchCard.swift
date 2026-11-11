import KiwiDeskCore
import SwiftUI

/// The Space switch card (#3218): how a switch shows itself, the
/// scroll step's twin and the slide's pace. App-wide (#1741), so
/// it is a card of its own under `LiveSettingNote`, after the
/// profile's Animations card, and outside Reduce Motion's grey:
/// the slide falls back to Show the Space there (#2524).
struct SpaceSwitchCard: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        SettingsSection(
            SettingsCatalog.colors.spaceSwitchCard,
            caption: LiveSettingNote.text,
            captionProminent: true
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(ColorsRowOrder.spaceSwitch, id: \.id) { key in
                    row(for: key).modifier(GreyOut(active: greyed(key)))
                }
            }
        }
    }

    /// The duration greys while neither pick draws a slide (#2524,
    /// #2971); the pickers' Lua gate is the census's.
    private func greyed(_ key: SettingKey) -> Bool {
        key == .colours(.spaceSlideDuration) && spaceSlideDurationInert
    }

    @ViewBuilder private func row(for key: SettingKey) -> some View {
        switch key {
        case .colours(.spaceTransition): spaceTransitionRow
        case .colours(.spaceScrollTransition): spaceScrollTransitionRow
        case .colours(.spaceSlideDuration): spaceSlideDurationRow
        default:
            let _ = assertionFailure(
                "unrendered Space switch census key: \(key.id)"
            )
            EmptyView()
        }
    }
}
