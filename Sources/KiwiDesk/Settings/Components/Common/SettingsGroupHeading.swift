import SwiftUI

/// A heading inside a card, one per group of rows. A heading
/// after the first follows a group's closing rule, and stands
/// farther from it than from its own rows.
struct SettingsGroupHeading: View {
    let title: String
    var followsGroup = false

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(SettingsTheme.groupHeading)
            .textCase(.uppercase)
            .padding(.top, followsGroup ? 14 : 6)
            .accessibilityAddTraits(.isHeader)
    }
}
